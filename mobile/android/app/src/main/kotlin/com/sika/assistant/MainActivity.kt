package com.sika.assistant

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity : requis par local_auth (biométrie). Aucun service natif en arrière-plan :
// l'assistant vocal fonctionne dans l'app (Gemini Live), le micro n'est jamais écouté app fermée.
class MainActivity : FlutterFragmentActivity()
