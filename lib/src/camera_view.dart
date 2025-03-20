import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'camera_overlay.dart';

class MRZCameraView extends StatefulWidget {
  const MRZCameraView({
    super.key,
    required this.onImage,
    this.initialDirection = CameraLensDirection.back,
    required this.showOverlay,
  });

  final Function(InputImage inputImage) onImage;
  final CameraLensDirection initialDirection;
  final bool showOverlay;

  @override
  _MRZCameraViewState createState() => _MRZCameraViewState();
}

class _MRZCameraViewState extends State<MRZCameraView> {
  CameraController? _controller;
  int _cameraIndex = 0;
  List<CameraDescription> cameras = [];

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  initCamera() async {
    cameras = await availableCameras();

    try {
      if (cameras.any((element) => element.lensDirection == widget.initialDirection && element.sensorOrientation == 90)) {
        _cameraIndex = cameras.indexOf(
          cameras.firstWhere(
            (element) => element.lensDirection == widget.initialDirection && element.sensorOrientation == 90,
          ),
        );
      } else {
        _cameraIndex = cameras.indexOf(
          cameras.firstWhere(
            (element) => element.lensDirection == widget.initialDirection,
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    _startLiveFeed();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.showOverlay ? MRZCameraOverlay(child: _liveFeedBody()) : _liveFeedBody(),
    );
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized == false || _controller?.value.isInitialized == null) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: CameraPreview(_controller!),
          ),
        ],
      ),
    );
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }

      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _processCameraImage(CameraImage image) async {
    final imageRotation = InputImageRotation.rotation90deg;

    final inputImageFormat = getInputFormat(image.format.group);

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );

    widget.onImage(inputImage);
  }

  InputImageFormat getInputFormat(ImageFormatGroup group) {
    debugPrint('');
    if (Platform.isAndroid) {
      switch (group) {
        case ImageFormatGroup.nv21:
          return InputImageFormat.nv21;
        case ImageFormatGroup.yuv420:
          return InputImageFormat.yuv_420_888;
        default:
          return InputImageFormat.yv12;
      }
    } else {
      switch (group) {
        case ImageFormatGroup.bgra8888:
          return InputImageFormat.bgra8888;
        default:
          return InputImageFormat.yuv420;
      }
    }
  }
}
