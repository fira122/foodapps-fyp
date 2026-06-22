import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:io';

enum FaceAuthMode { enroll, login, authenticate }

class FaceAuthScreen extends StatefulWidget {
  final FaceAuthMode mode;
  final String userId;

  const FaceAuthScreen({
    super.key,
    required this.mode,
    required this.userId,
  });

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  CameraController? _cameraCtrl;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  String _statusMessage = "Align your face inside the frame";
  bool _isFaceValid = false;
  String? _cameraError;
  CameraDescription? _frontCameraDescription;

  // Liveness validation states
  bool _hasBlinked = false;
  bool _eyesClosedChecked = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _cameraError = "No cameras found on device.");
        return;
      }

      _frontCameraDescription = _cameras!.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraCtrl = CameraController(
        _frontCameraDescription!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraCtrl!.initialize();
      if (!mounted) return;

      setState(() {});

      _cameraCtrl!.startImageStream((CameraImage image) {
        if (_isProcessing) return;
        _isProcessing = true;
        _processCameraImage(image);
      });
    } catch (e) {
      setState(() => _cameraError = "Camera access denied or initiation failed.");
    }
  }

  InputImage? _buildInputImageFromCamera(CameraImage image) {
    if (_cameraCtrl == null || _frontCameraDescription == null) return null;

    final sensorOrientation = _frontCameraDescription!.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      switch (_cameraCtrl!.value.deviceOrientation) {
        case DeviceOrientation.portraitUp: rotationCompensation = 0; break;
        case DeviceOrientation.landscapeLeft: rotationCompensation = 90; break;
        case DeviceOrientation.portraitDown: rotationCompensation = 180; break;
        case DeviceOrientation.landscapeRight: rotationCompensation = 270; break;
      }
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

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
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _buildInputImageFromCamera(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _isFaceValid = false;
          _statusMessage = "No face detected. Look at the camera.";
        });
        _isProcessing = false;
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _isFaceValid = false;
          _statusMessage = "Multiple faces detected. Scan alone.";
        });
        _isProcessing = false;
        return;
      }

      Face face = faces.first;

      // 1. STRICT OVAL BOUNDING ANALYSIS (Prevents background registration leaks)
      final Size screenSize = MediaQuery.of(context).size;
      final double targetCenterX = screenSize.width / 2;
      final double targetCenterY = screenSize.height / 2;

      final double scaleX = screenSize.width / image.height;
      final double scaleY = screenSize.height / image.width;

      final double faceCenterX = (face.boundingBox.left + face.boundingBox.width / 2) * scaleX;
      final double faceCenterY = (face.boundingBox.top + face.boundingBox.height / 2) * scaleY;

      final double ovalWidth = screenSize.width * 0.72;
      final double ovalHeight = screenSize.width * 0.95;

      // Verification matrix checks if the facial center aligns directly with the target frame center
      final bool isProperlyCentered = (faceCenterX > (targetCenterX - ovalWidth * 0.25)) &&
          (faceCenterX < (targetCenterX + ovalWidth * 0.25)) &&
          (faceCenterY > (targetCenterY - ovalHeight * 0.25)) &&
          (faceCenterY < (targetCenterY + ovalHeight * 0.25));

      final bool isCorrectSize = (face.boundingBox.width * scaleX >= ovalWidth * 0.55);

      if (!isProperlyCentered || !isCorrectSize) {
        setState(() {
          _isFaceValid = false;
          _statusMessage = "Align your face directly inside the oval frame.";
        });
        _isProcessing = false;
        return;
      }

      // 2. LANDMARK EXTRACTION MANDATE
      final leftEye   = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye  = face.landmarks[FaceLandmarkType.rightEye];
      final nose      = face.landmarks[FaceLandmarkType.noseBase];
      final mouthBase = face.landmarks[FaceLandmarkType.bottomMouth];

      if (leftEye == null || rightEye == null || nose == null || mouthBase == null) {
        setState(() {
          _isFaceValid = false;
          _statusMessage = "Face covered! Clear your eyes, nose, and mouth.";
        });
        _isProcessing = false;
        return;
      }

      // 3. RELAXED HEAD DIRECTION TOLERANCE (Much faster tracking)
      final double headYaw = face.headEulerAngleY ?? 0;
      final double headPitch = face.headEulerAngleX ?? 0;
      if (headYaw.abs() > 22 || headPitch.abs() > 22) {
        setState(() {
          _isFaceValid = false;
          _statusMessage = "Look straight directly into the camera.";
        });
        _isProcessing = false;
        return;
      }

      setState(() { _isFaceValid = true; });

      // 4. LIVENESS CHECK (Eye Blink Sequence)
      if (!_hasBlinked) {
        final double leftOpenProb = face.leftEyeOpenProbability ?? 1.0;
        final double rightOpenProb = face.rightEyeOpenProbability ?? 1.0;

        setState(() {
          _statusMessage = "Please blink your eyes to verify you are real.";
        });

        if (!_eyesClosedChecked && leftOpenProb < 0.20 && rightOpenProb < 0.20) {
          _eyesClosedChecked = true;
        }

        if (_eyesClosedChecked && leftOpenProb > 0.70 && rightOpenProb > 0.70) {
          _hasBlinked = true;
        }

        _isProcessing = false;
        return;
      }

      setState(() { _statusMessage = "Verifying face..."; });

      // 5. OPERATION MODE ROUTING
      if (widget.mode == FaceAuthMode.enroll) {
        await _saveFaceToDatabase(face);
      } else {
        await _handleAuthentication(face);
      }

    } catch (e) {
      debugPrint("Engine Error: $e");
      _isProcessing = false;
    }
  }

  // RE-ENGINEERED: Normalized Vector Space Feature Mapping
  Map<String, double> _extractNormalizedBiometrics(Face face) {
    final pLeftEye   = face.landmarks[FaceLandmarkType.leftEye]!.position;
    final pRightEye  = face.landmarks[FaceLandmarkType.rightEye]!.position;
    final pNose      = face.landmarks[FaceLandmarkType.noseBase]!.position;
    final pMouthBase = face.landmarks[FaceLandmarkType.bottomMouth]!.position;

    // Use eye-to-eye distance as base unit scaling factor (immune to depth/distance changes)
    double baseUnit = sqrt(pow(pLeftEye.x - pRightEye.x, 2) + pow(pLeftEye.y - pRightEye.y, 2));
    if (baseUnit == 0) baseUnit = 1.0;

    // Map biometric distances using normalized scalar values
    double noseToLeftEye = sqrt(pow(pNose.x - pLeftEye.x, 2) + pow(pNose.y - pLeftEye.y, 2)) / baseUnit;
    double noseToRightEye = sqrt(pow(pNose.x - pRightEye.x, 2) + pow(pNose.y - pRightEye.y, 2)) / baseUnit;
    double noseToMouth = sqrt(pow(pNose.x - pMouthBase.x, 2) + pow(pNose.y - pMouthBase.y, 2)) / baseUnit;
    double leftEyeToMouth = sqrt(pow(pLeftEye.x - pMouthBase.x, 2) + pow(pLeftEye.y - pMouthBase.y, 2)) / baseUnit;
    double rightEyeToMouth = sqrt(pow(pRightEye.x - pMouthBase.x, 2) + pow(pRightEye.y - pMouthBase.y, 2)) / baseUnit;

    return {
      "v1": noseToLeftEye,
      "v2": noseToRightEye,
      "v3": noseToMouth,
      "v4": leftEyeToMouth,
      "v5": rightEyeToMouth,
    };
  }

  Future<void> _saveFaceToDatabase(Face face) async {
    await _cameraCtrl?.stopImageStream();
    final features = _extractNormalizedBiometrics(face);

    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'faceEnrolled': true,
      'faceFeatures': features,
    });

    setState(() => _statusMessage = "Enrollment successful!");
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _handleAuthentication(Face face) async {
    await _cameraCtrl?.stopImageStream();
    final currentFeatures = _extractNormalizedBiometrics(face);

    // ROUTE A: Global matching loop for user identification at sign-in
    if (widget.mode == FaceAuthMode.login || widget.userId.trim().isEmpty) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('faceEnrolled', isEqualTo: true)
          .get();

      for (var doc in querySnapshot.docs) {
        if (doc.data()['faceFeatures'] != null) {
          final saved = Map<String, dynamic>.from(doc.data()['faceFeatures']);

          double totalVariance = 0.0;
          totalVariance += (currentFeatures["v1"]! - saved["v1"]).abs();
          totalVariance += (currentFeatures["v2"]! - saved["v2"]).abs();
          totalVariance += (currentFeatures["v3"]! - saved["v3"]).abs();
          totalVariance += (currentFeatures["v4"]! - saved["v4"]).abs();
          totalVariance += (currentFeatures["v5"]! - saved["v5"]).abs();

          // Validation variance threshold (< 0.35 total across 5 biometric checks)
          if (totalVariance < 0.35) {
            setState(() => _statusMessage = "Welcome Back!");
            await Future.delayed(const Duration(milliseconds: 1000));
            if (!mounted) return;

            // Clean exit passing matching target ID back to login orchestrator
            Navigator.pop(context, doc.id);
            return;
          }
        }
      }

      setState(() => _statusMessage = "Face recognition failed. No match found.");
      _resetBlinkAndRestart();
      return;
    }

    // ROUTE B: Targeted verification matching against a specific user ID
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (!snapshot.exists || snapshot.data()?['faceFeatures'] == null) {
      setState(() => _statusMessage = "No biometric profile found.");
      _resetBlinkAndRestart();
      return;
    }

    final saved = Map<String, dynamic>.from(snapshot.data()!['faceFeatures']);
    double totalVariance = 0.0;
    totalVariance += (currentFeatures["v1"]! - saved["v1"]).abs();
    totalVariance += (currentFeatures["v2"]! - saved["v2"]).abs();
    totalVariance += (currentFeatures["v3"]! - saved["v3"]).abs();
    totalVariance += (currentFeatures["v4"]! - saved["v4"]).abs();
    totalVariance += (currentFeatures["v5"]! - saved["v5"]).abs();

    if (totalVariance < 0.35) {
      setState(() => _statusMessage = "Identity Confirmed!");
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() => _statusMessage = "Face recognition mismatch.");
      _resetBlinkAndRestart();
    }
  }

  void _resetBlinkAndRestart() {
    // FIX: Safely handle verification failures without locking the UI or crashing the view
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _hasBlinked = false;
          _eyesClosedChecked = false;
          _statusMessage = "Align your face inside the frame";
          _isProcessing = false;
        });

        // Re-engage stream processing loop
        if (_cameraCtrl != null && !_cameraCtrl!.value.isStreamingImages) {
          _cameraCtrl!.startImageStream((CameraImage img) {
            if (_isProcessing) return;
            _isProcessing = true;
            _processCameraImage(img);
          });
        }
      }
    });
  }

  Widget _buildErrorScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              Text(_cameraError!, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Go Back", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) return _buildErrorScaffold();
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.orange)));
    }

    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pop(context, false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
            children: [
            SizedBox(width: size.width, height: size.height, child: CameraPreview(_cameraCtrl!)),
        ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.65), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(color: Colors.transparent),
              Center(
                child: Container(
                  width: size.width * 0.72,
                  height: size.width * 0.95,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.all(Radius.elliptical(size.width * 0.72, size.width * 0.95)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: size.width * 0.72,
            height: size.width * 0.95,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isFaceValid ? (_hasBlinked ? Colors.green : Colors.blueAccent) : Colors.redAccent,
                width: 3.5,
              ),
              borderRadius: BorderRadius.all(Radius.elliptical(size.width * 0.72, size.width * 0.95)),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context, false),
              ),
              const Spacer(),
              Text(
                widget.mode == FaceAuthMode.enroll ? 'Set Up Face Login' : 'Face Login',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      Positioned(
        bottom: 40, left: 24, right: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isFaceValid ? Colors.greenAccent : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      ],
    ),
    ),
    );
  }
}