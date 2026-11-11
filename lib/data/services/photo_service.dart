import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/result.dart';

/// Takes a photo with the camera (no gallery).
abstract interface class PhotoService {
  /// A JPEG no larger than [maxSide] px on its long side; `Ok(null)` when the user
  /// closed the camera without taking one.
  Future<Result<Uint8List?>> takePhoto({
    required double maxSide,
    required int quality,
  });

  /// Up to [limit] photos chosen from the gallery, resized like a camera shot; an empty
  /// list when the user closed the picker without choosing.
  Future<Result<List<Uint8List>>> pickFromGallery({
    required double maxSide,
    required int quality,
    required int limit,
  });

  /// A photo taken just before Android killed the app while the camera was open; null
  /// when there is none.
  Future<Uint8List?> recoverLostPhoto();
}

class ImagePickerPhotoService implements PhotoService {
  ImagePickerPhotoService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<Result<Uint8List?>> takePhoto({
    required double maxSide,
    required int quality,
  }) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality,
      );
      return Ok(file == null ? null : await file.readAsBytes());
    } catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Result<List<Uint8List>>> pickFromGallery({
    required double maxSide,
    required int quality,
    required int limit,
  }) async {
    try {
      final List<XFile> files;
      if (limit <= 1) {
        final one = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: maxSide,
          maxHeight: maxSide,
          imageQuality: quality,
        );
        files = [?one];
      } else {
        files = await _picker.pickMultiImage(
          maxWidth: maxSide,
          maxHeight: maxSide,
          imageQuality: quality,
          limit: limit,
        );
      }
      // Some phones ignore the limit: the rest is dropped here.
      return Ok([for (final f in files.take(limit)) await f.readAsBytes()]);
    } catch (e) {
      return Failure(e);
    }
  }

  @override
  Future<Uint8List?> recoverLostPhoto() async {
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file ?? lost.files?.firstOrNull;
      return lost.isEmpty || file == null ? null : await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

/// A camera that hands out the photos it was given: tests and runs without a camera.
class ScriptedPhotoService implements PhotoService {
  ScriptedPhotoService(
    this.photos, {
    this.error = false,
    this.lost,
    this.gallery = const [],
  });

  /// What the gallery hands out, one pick at a time (an empty pick = closed).
  final List<List<Uint8List>> gallery;
  int galleryOpened = 0;

  /// The next photos, in order; `null` is a closed camera.
  final List<Uint8List?> photos;
  final bool error;
  final Uint8List? lost;
  int taken = 0;

  @override
  Future<Result<Uint8List?>> takePhoto({
    required double maxSide,
    required int quality,
  }) async {
    taken++;
    if (error) return const Failure('camera');
    return Ok(photos.isEmpty ? null : photos.removeAt(0));
  }

  @override
  Future<Result<List<Uint8List>>> pickFromGallery({
    required double maxSide,
    required int quality,
    required int limit,
  }) async {
    galleryOpened++;
    if (error) return const Failure('gallery');
    final pick = gallery.length >= galleryOpened
        ? gallery[galleryOpened - 1]
        : const <Uint8List>[];
    return Ok(pick.take(limit).toList());
  }

  @override
  Future<Uint8List?> recoverLostPhoto() async => lost;
}

final photoServiceProvider = Provider<PhotoService>(
  (ref) => ImagePickerPhotoService(),
);
