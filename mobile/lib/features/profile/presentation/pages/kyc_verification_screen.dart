import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/sika_surface.dart';


class KycVerificationScreen extends ConsumerStatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  ConsumerState<KycVerificationScreen> createState() =>
      _KycVerificationScreenState();
}

class _KycVerificationScreenState extends ConsumerState<KycVerificationScreen> {
  int _currentStep = 0; // 0: ID Front, 1: ID Back, 2: Selfie
  bool _isProcessing = false;

  bool _isTargetDetected = false;
  DateTime? _targetDetectionTime;
  String _feedbackMessage = '';

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
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
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

    InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation);
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

      if (_currentStep < 2) {
        // ID Card Auto-Scan logic
        final RecognizedText recognizedText =
            await _textRecognizer.processImage(inputImage);
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
          if (face.headEulerAngleY != null &&
              face.headEulerAngleY!.abs() > 15) {
            feedback = 'Regardez droit devant vous.';
          } else {
            targetFound = true;
            feedback = 'Visage détecté. Ne bougez pas...';
          }
        } else if (faces.isEmpty) {
          feedback = 'Aucun visage détecté.';
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
            DateTime.now().difference(_targetDetectionTime!) >
                const Duration(seconds: 3)) {
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.stopImageStream();
    } catch (e) {
      // Ignore
    }

    try {
      final XFile picture = await _cameraController!.takePicture();

      setState(() {
        _isTargetDetected = false;
        _targetDetectionTime = null;
        _feedbackMessage = '';
        if (_currentStep == 0) {
          _currentStep = 1;
        } else if (_currentStep == 1) {
          _currentStep = 2;
        } else if (_currentStep == 2) {
          _selfieImage = File(picture.path);
        }
      });

      _isDetecting = false;

      if (_currentStep == 2 && _selfieImage == null) {
        int frontIndex = _cameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        if (frontIndex != -1) {
          _isCameraInitialized = false;
          await _startCamera(frontIndex);
        } else {
          await _startCamera(0); 
        }
      } else if (_selfieImage != null) {
        _submitKyc();
      } else {
        await _startCamera(_currentCameraIndex);
      }
    } catch (e) {
      debugPrint("Error taking auto picture: $e");
      _isDetecting = false;
    }
  }

  Future<void> _submitKyc() async {
    setState(() => _isProcessing = true);
    final langNotifier = ref.read(languageProvider.notifier);
    try {
      await ref.read(authProvider.notifier).submitKyc();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langNotifier.tr(
              'Documents envoyés. Votre vérification est en attente.',
              'Documents sent. Your verification is pending.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langNotifier.tr(
              "L'envoi a échoué. Vérifiez votre connexion et réessayez.",
              'Sending failed. Check your connection and try again.')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildProgressSegment(int stepIndex) {
    bool isActive = _currentStep >= stepIndex;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.darkBorderSubtle,
          borderRadius: AppSpacing.borderRadiusSm,
        ),
      ),
    );
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

    // Forces dark theme for the camera UI elements for contrast
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black, // Camera screen is dark
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            langNotifier.tr('Vérification d\'identité', 'Identity Verification'),
            style: AppTypography.h3.copyWith(color: Colors.white),
          ),
        ),
        body: _isProcessing
            ? Container(
                width: double.infinity,
                color: AppColors.darkBackground,
                child: Center(
                  child: SikaSurface(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          langNotifier.tr(
                              'Vérification sécurisée en cours...', 'Secure verification in progress...'),
                          style: AppTypography.bodyMediumStrong.copyWith(color: AppColors.darkTextPrimary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Camera & Overlay
                  if (_isCameraInitialized && _cameraController != null)
                    Stack(
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
                      ],
                    )
                  else
                    const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),

                  // 2. Top UI (Progress & Instructions)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.md,
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: Column(
                      children: [
                        // Progress Indicator
                        Row(
                          children: [
                            _buildProgressSegment(0),
                            _buildProgressSegment(1),
                            _buildProgressSegment(2),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Instructions Container
                        SikaSurface(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _currentStep == 0
                                  ? langNotifier.tr('Étape 1 : Recto', 'Step 1: Front')
                                  : _currentStep == 1
                                      ? langNotifier.tr('Étape 2 : Verso', 'Step 2: Back')
                                      : langNotifier.tr('Étape 3 : Selfie', 'Step 3: Selfie'),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _currentStep == 0
                                    ? langNotifier.tr(
                                        'Placez l\'avant de votre carte d\'identité dans le cadre.',
                                        'Place the front of your ID in the frame.')
                                    : _currentStep == 1
                                        ? langNotifier.tr(
                                            'Retournez votre pièce et placez le verso dans le cadre.',
                                            'Turn your ID over and place the back in the frame.')
                                        : langNotifier.tr(
                                            'Regardez droit devant vous et maintenez votre visage dans le cercle.',
                                            'Look straight ahead and keep your face in the circle.'),
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMediumStrong.copyWith(color: AppColors.darkTextPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Feedback Message
                  if (_feedbackMessage.isNotEmpty)
                    Positioned(
                      bottom: 60,
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      child: SikaSurface(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isTargetDetected) ...[
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            Flexible(
                              child: Text(
                                _feedbackMessage,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMediumStrong.copyWith(
                                    color: _isTargetDetected
                                        ? AppColors.success
                                        : AppColors.darkTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final bool isCircle;
  final bool isTargetDetected;
  ScannerOverlayPainter(
      {required this.isCircle, this.isTargetDetected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.7);

    // Create the cutout path
    Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path cutoutPath = Path();

    if (isCircle) {
      cutoutPath.addOval(Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 300,
          height: 300));
    } else {
      double w = size.width * 0.85;
      double h = w * 0.63; // ID card aspect ratio
      cutoutPath.addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: w,
              height: h),
          const Radius.circular(16)));
    }

    // Combine paths to create the hole
    final finalPath =
        Path.combine(PathOperation.difference, overlayPath, cutoutPath);
    canvas.drawPath(finalPath, paint);

    // Draw a border around the cutout
    final borderPaint = Paint()
      ..color = isTargetDetected ? AppColors.success : AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTargetDetected ? 4.0 : 2.0;
    canvas.drawPath(cutoutPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.isCircle != isCircle ||
        oldDelegate.isTargetDetected != isTargetDetected;
  }
}
