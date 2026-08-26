import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class KycVerificationScreen extends ConsumerStatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  ConsumerState<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends ConsumerState<KycVerificationScreen> {
  int _currentStep = 0; // 0: ID Front, 1: ID Back, 2: Selfie
  bool _isProcessing = false;
  
  bool _isTargetDetected = false;
  DateTime? _targetDetectionTime;
  String _feedbackMessage = '';
  File? _idCardFront;
  File? _idCardBack;
  File? _selfieImage;

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _currentCameraIndex = 0;
  bool _isCameraInitialized = false;

  // ML Kit Variables
  bool _isDetecting = false;
  late final FaceDetector _faceDetector;
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _startCamera(0); // Rear camera initially
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> _startCamera(int cameraIndex) async {
    if (_cameras.isEmpty) return;
    
    _currentCameraIndex = cameraIndex;
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Start processing images for auto-scan
        _cameraController!.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameras.isEmpty) return null;
    final camera = _cameras[_currentCameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isDetecting || _isProcessing) return;
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      bool targetFound = false;
      String feedback = '';

      if (_currentStep < 3) {
        // ID Card Auto-Scan logic
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        if (recognizedText.text.length > 50) { 
          targetFound = true;
          feedback = 'Carte détectée. Maintenez...';
        } else {
          feedback = 'Placez la carte dans le cadre.';
        }
      } else {
        // Selfie Auto-Scan logic
        final List<Face> faces = await _faceDetector.processImage(inputImage);
        if (faces.length == 1) {
          final face = faces.first;
          if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 15) {
             feedback = 'Regardez droit devant vous.';
          } else {
             targetFound = true;
             feedback = 'Visage détecté. Ne bougez pas...';
          }
        } else if (faces.isEmpty) {
          feedback = 'Aucun visage détecté ou espace sombre.';
        } else {
          feedback = 'Un seul visage autorisé.';
        }
      }

      if (targetFound) {
        if (!_isTargetDetected) {
          if (mounted) {
            setState(() {
              _isTargetDetected = true;
              _targetDetectionTime = DateTime.now();
              _feedbackMessage = feedback;
            });
          }
          _isDetecting = false;
        } else if (_targetDetectionTime != null && 
                   DateTime.now().difference(_targetDetectionTime!) > const Duration(seconds: 2)) {
          await _triggerAutoCapture();
        } else {
          if (mounted && _feedbackMessage != feedback) {
            setState(() {
              _feedbackMessage = feedback;
            });
          }
          _isDetecting = false;
        }
      } else {
        if (_isTargetDetected) {
          if (mounted) {
            setState(() {
              _isTargetDetected = false;
              _targetDetectionTime = null;
              _feedbackMessage = feedback;
            });
          }
        } else if (_feedbackMessage != feedback) {
          if (mounted) {
            setState(() {
               _feedbackMessage = feedback;
            });
          }
        }
        _isDetecting = false;
      }
    } catch (e) {
      debugPrint("ML Kit processing error: $e");
      _isDetecting = false;
    }
  }

  Future<void> _triggerAutoCapture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    // Stop the image stream before taking a picture
    try {
      await _cameraController!.stopImageStream();
    } catch (e) {
      // Stream might already be stopped
    }

    try {
      final XFile picture = await _cameraController!.takePicture();
      
      setState(() {
        _isTargetDetected = false;
        _targetDetectionTime = null;
        _feedbackMessage = '';
        if (_currentStep == 0) {
          _idCardFront = File(picture.path);
          _currentStep = 1;
        } else if (_currentStep == 1) {
          _idCardBack = File(picture.path);
          _currentStep = 2;
        } else if (_currentStep == 2) {
          _selfieImage = File(picture.path);
        }
      });
      
      _isDetecting = false;
      
      if (_currentStep == 2 && _selfieImage == null) {
         // We just moved to step 2
         int frontIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
         if (frontIndex != -1) {
           _isCameraInitialized = false;
           await _startCamera(frontIndex);
         } else {
           await _startCamera(0); // Fallback
         }
      } else if (_selfieImage != null) {
         _submitKyc();
      } else {
         // Restart stream for next step
         await _startCamera(_currentCameraIndex);
      }

    } catch (e) {
      debugPrint("Error taking auto picture: $e");
      _isDetecting = false;
    }
  }

  Future<void> _submitKyc() async {
    setState(() => _isProcessing = true);
    
    // Simulate API verification
    await Future.delayed(const Duration(seconds: 2));
    
    ref.read(authProvider.notifier).updateKycStatus(true);
    
    if (mounted) {
      final langNotifier = ref.read(languageProvider.notifier);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langNotifier.tr('Identité vérifiée par IA avec succès !', 'Identity verified by AI successfully!')),
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    _textRecognizer.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langNotifier = ref.watch(languageProvider.notifier);
    
    return Scaffold(
      backgroundColor: Colors.black, // Camera screen is dark
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentStep == 0 ? langNotifier.tr('Scanner Recto (Auto)', 'Scan Front (Auto)')
          : _currentStep == 1 ? langNotifier.tr('Scanner Verso (Auto)', 'Scan Back (Auto)')
          : langNotifier.tr('Selfie (Auto)', 'Selfie (Auto)'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isProcessing 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  const SizedBox(height: 24),
                  Text(
                    langNotifier.tr('Vérification IA en cours...', 'AI Verifying...'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              )
            : Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 0 ? AppColors.primary : Colors.grey[800],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 1 ? AppColors.primary : Colors.grey[800],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 2 ? AppColors.primary : Colors.grey[800],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                _currentStep == 0 ? langNotifier.tr('Placez l\'avant de votre carte dans le cadre. L\'IA scannera automatiquement.', 'Place the front of your ID in the frame. AI will scan automatically.')
                : _currentStep == 1 ? langNotifier.tr('Placez l\'arrière de votre carte. Le scan est automatique.', 'Place the back of your ID. Scan is automatic.')
                : langNotifier.tr('Placez votre visage dans le cercle. La photo se prendra toute seule.', 'Place your face in the circle. It will capture automatically.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            
            // Camera Preview with Overlay
            Expanded(
              child: _isCameraInitialized && _cameraController != null
                  ? Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        CustomPaint(
                          painter: ScannerOverlayPainter(
                            isCircle: _currentStep == 2,
                            isTargetDetected: _isTargetDetected,
                          ),
                          child: Container(),
                        ),
                        if (_feedbackMessage.isNotEmpty)
                          Positioned(
                            bottom: 60,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _feedbackMessage,
                                style: TextStyle(
                                  color: _isTargetDetected ? AppColors.emerald : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            
            // The capture button is hidden since we are using Auto-Scan!
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final bool isCircle;
  final bool isTargetDetected;
  ScannerOverlayPainter({required this.isCircle, this.isTargetDetected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.7);
    
    // Create the cutout path
    Path overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path cutoutPath = Path();

    if (isCircle) {
      cutoutPath.addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2), 
        width: 300, 
        height: 300
      ));
    } else {
      double w = size.width * 0.85;
      double h = w * 0.63; // ID card aspect ratio
      cutoutPath.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: w, height: h),
        const Radius.circular(16)
      ));
    }

    // Combine paths to create the hole
    final finalPath = Path.combine(PathOperation.difference, overlayPath, cutoutPath);
    canvas.drawPath(finalPath, paint);

    // Draw a border around the cutout
    final borderPaint = Paint()
      ..color = isTargetDetected ? AppColors.emerald : AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTargetDetected ? 5.0 : 3.0;
    canvas.drawPath(cutoutPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.isCircle != isCircle || oldDelegate.isTargetDetected != isTargetDetected;
  }
}
