package com.sika.assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

enum class ServiceState {
    STOPPED,            // Wake Word désactivé ou service arrêté
    LISTENING,          // Écoute active
    PAUSED_FOR_FLUTTER  // Suspendu car Flutter utilise le microphone
}

class SikaWakeWordServiceV2 : Service() {

    companion object {
        private const val TAG = "SikaWakeWordServiceV2"
        private const val CHANNEL_ID = "SikaWakeWordChannel"
        private const val NOTIFICATION_ID = 2001

        const val ACTION_WAKE_WORD_DETECTED = "com.gertonargent.WAKE_WORD_DETECTED"
        const val ACTION_STOP_LISTENING = "com.gertonargent.STOP_LISTENING"
        
        var currentState: ServiceState = ServiceState.STOPPED
            private set
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private lateinit var flutterPrefs: SharedPreferences
    private lateinit var sikaPrefs: SharedPreferences
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "======== SikaWakeWordServiceV2.onCreate() ========")
        flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        sikaPrefs = getSharedPreferences("sika_prefs", MODE_PRIVATE)
        createNotificationChannel()
    }

    private fun isWakeWordEnabled(): Boolean {
        // Flutter shared_preferences utilizes the "flutter." prefix
        return flutterPrefs.getBoolean("flutter.wake_word_enabled", true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isWakeWordEnabled()) {
            Log.d(TAG, "Wake Word is disabled in preferences. Stopping service immediately.")
            stopListening(forceStop = true)
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent?.action) {
            ACTION_STOP_LISTENING -> {
                Log.d(TAG, "Received ACTION_STOP_LISTENING")
                stopListening(forceStop = true)
                stopSelf()
                return START_NOT_STICKY
            }
            "com.gertonargent.PAUSE_LISTENING" -> {
                Log.d(TAG, "Received PAUSE_LISTENING -> Pausing Wake Word to free microphone")
                currentState = ServiceState.PAUSED_FOR_FLUTTER
                stopListening(forceStop = false)
                return START_STICKY
            }
            "com.gertonargent.RESUME_LISTENING" -> {
                Log.d(TAG, "Received RESUME_LISTENING -> Resuming Wake Word")
                if (currentState == ServiceState.PAUSED_FOR_FLUTTER || currentState == ServiceState.STOPPED) {
                    startWakeWordDetection()
                }
                return START_STICKY
            }
            else -> {
                startForeground(NOTIFICATION_ID, createNotification())
                if (currentState == ServiceState.STOPPED) {
                    Log.d(TAG, "Starting service for the first time")
                    startWakeWordDetection()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy called")
        stopListening(forceStop = true)
    }

    private fun startWakeWordDetection() {
        if (!isWakeWordEnabled()) {
            stopListening(forceStop = true)
            stopSelf()
            return
        }
        if (currentState == ServiceState.LISTENING) return
        
        currentState = ServiceState.LISTENING
        Log.d(TAG, "Starting continuous SpeechRecognizer for Wake Word detection...")
        
        mainHandler.post {
            try {
                speechRecognizer?.destroy()
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "fr-FR")
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 5000)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000)
                }

                val listener = object : RecognitionListener {
                    override fun onReadyForSpeech(params: android.os.Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    
                    override fun onError(error: Int) {
                        if (currentState == ServiceState.LISTENING) restartWakeWordDetection(1000)
                    }
                    
                    override fun onResults(results: android.os.Bundle?) {
                        handleSTTResults(results)
                    }
                    
                    override fun onPartialResults(partialResults: android.os.Bundle?) {}
                    override fun onEvent(eventType: Int, params: android.os.Bundle?) {}
                }

                speechRecognizer?.setRecognitionListener(listener)
                speechRecognizer?.startListening(intent)
                Log.d(TAG, "✅ Wake Word Detector active")
            } catch (e: Exception) {
                Log.e(TAG, "Error starting STT: ${e.message}", e)
                if (currentState == ServiceState.LISTENING) restartWakeWordDetection(2000)
            }
        }
    }

    private fun handleSTTResults(results: android.os.Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (matches.isNullOrEmpty()) {
            if (currentState == ServiceState.LISTENING) restartWakeWordDetection(500)
            return
        }

        val command = matches[0].lowercase(Locale.getDefault())
        Log.d(TAG, "🎤 Recognized: \"$command\"")

        val universalWakeWord = "sika"
        // Le nom de l'assistant enregistré depuis Flutter via MethodChannel -> sika_prefs
        val customWakeWord = sikaPrefs.getString("sika_assistant_name", "sika")?.lowercase(Locale.getDefault()) ?: "sika"

        if (command.contains(universalWakeWord) || command.contains(customWakeWord)) {
            Log.d(TAG, "======== WAKE-WORD DETECTED: $command ========")
            onWakeWordDetected(if (command.contains(customWakeWord)) customWakeWord else universalWakeWord)
        } else {
            if (currentState == ServiceState.LISTENING) restartWakeWordDetection(500)
        }
    }

    private fun onWakeWordDetected(detectedAlias: String) {
        // Mettre en pause car Flutter va prendre le relais
        currentState = ServiceState.PAUSED_FOR_FLUTTER
        stopListening(forceStop = false)

        val intent = Intent(ACTION_WAKE_WORD_DETECTED)
        intent.putExtra("detectedAlias", detectedAlias)
        sendBroadcast(intent)
    }

    private fun stopListening(forceStop: Boolean) {
        if (forceStop) {
            currentState = ServiceState.STOPPED
        }
        // CLEANUP: suppression inconditionnelle de tout callback retardé qui relancerait l'écoute
        mainHandler.removeCallbacksAndMessages(null)
        
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error destroying recognizer", e)
            }
        }
    }

    private fun restartWakeWordDetection(delayMs: Long) {
        if (currentState != ServiceState.LISTENING || !isWakeWordEnabled()) return
        mainHandler.post {
            try {
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (e: Exception) {}
        }
        mainHandler.postDelayed({
            if (currentState == ServiceState.LISTENING) startWakeWordDetection()
        }, delayMs)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Sika Assistant",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Écoute du Wake Word"
            channel.setShowBadge(false)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopIntent = Intent(this, SikaWakeWordServiceV2::class.java)
        stopIntent.action = ACTION_STOP_LISTENING
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sika vous écoute")
            .setContentText("Dites Sika pour parler")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pi)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
