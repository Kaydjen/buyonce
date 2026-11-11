import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';

/// Why the camera could not be opened.
enum CameraError {
  /// The user refused the permission.
  denied,

  /// No camera, or it failed to start.
  unavailable,
}

/// A camera that is open: a live preview, a shutter, a torch. The receipt screen works
/// with this and not with the plugin, so tests (and a phone without a camera) can use a
/// stand-in.
abstract interface class CameraSession {
  /// The live picture; tapping it focuses ([onFocus] gets a point in 0..1).
  Widget preview({required void Function(Offset point) onFocus});

  /// One JPEG of what the camera sees.
  Future<Result<Uint8List>> capture();

  /// The lamp on or off (small print needs light).
  Future<void> setTorch(bool on);

  Future<void> close();
}

abstract interface class ReceiptCamera {
  Future<Result<CameraSession>> open();
}

/// The phone's back camera through the `camera` plugin. 1080p keeps a shot at about
/// 1-2 MB, so three of them fit one request to Gemini without resizing; the gallery
/// photos are resized by the picker.
class DeviceCamera implements ReceiptCamera {
  const DeviceCamera();

  @override
  Future<Result<CameraSession>> open() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      final back = cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .firstOrNull;
      final chosen = back ?? cameras.firstOrNull;
      if (chosen == null) return const Failure(CameraError.unavailable);
      controller = CameraController(
        chosen,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      return Ok(_DeviceSession(controller));
    } on CameraException catch (e) {
      await controller?.dispose();
      final denied =
          e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted';
      return Failure(denied ? CameraError.denied : CameraError.unavailable);
    } catch (_) {
      await controller?.dispose();
      return const Failure(CameraError.unavailable);
    }
  }
}

class _DeviceSession implements CameraSession {
  _DeviceSession(this._controller);
  final CameraController _controller;

  @override
  Widget preview({required void Function(Offset point) onFocus}) {
    final ratio = _controller.value.aspectRatio; // landscape: width / height
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / ratio,
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final point = Offset(
                d.localPosition.dx / box.maxWidth,
                d.localPosition.dy / box.maxHeight,
              );
              _focus(point);
              onFocus(point);
            },
            child: CameraPreview(_controller),
          ),
        ),
      ),
    );
  }

  Future<void> _focus(Offset point) async {
    try {
      await _controller.setFocusPoint(point);
      await _controller.setExposurePoint(point);
    } catch (_) {}
  }

  @override
  Future<Result<Uint8List>> capture() async {
    try {
      final file = await _controller.takePicture();
      return Ok(await file.readAsBytes());
    } catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<void> setTorch(bool on) async {
    try {
      await _controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } catch (_) {}
  }

  @override
  Future<void> close() => _controller.dispose();
}

/// A camera for tests and runs without one: a plain box as the preview, and the shots it
/// was given, in order.
class ScriptedReceiptCamera implements ReceiptCamera {
  ScriptedReceiptCamera(this.shots, {this.error});

  final List<Uint8List> shots;

  /// When set, `open` fails with it.
  final CameraError? error;
  int opened = 0;
  int taken = 0;
  bool torch = false;
  bool closed = false;

  @override
  Future<Result<CameraSession>> open() async {
    if (error != null) return Failure(error!);
    opened++;
    return Ok(_ScriptedSession(this));
  }
}

class _ScriptedSession implements CameraSession {
  _ScriptedSession(this._camera);
  final ScriptedReceiptCamera _camera;

  @override
  Widget preview({required void Function(Offset point) onFocus}) =>
      const SizedBox.expand(key: Key('fakePreview'));

  @override
  Future<Result<Uint8List>> capture() async {
    _camera.taken++;
    if (_camera.shots.isEmpty) return const Failure('no more shots');
    return Ok(_camera.shots.removeAt(0));
  }

  @override
  Future<void> setTorch(bool on) async => _camera.torch = on;

  @override
  Future<void> close() async => _camera.closed = true;
}

final receiptCameraProvider = Provider<ReceiptCamera>(
  (ref) => const DeviceCamera(),
);
