import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/result.dart';
import '../../data/repositories/receipt_parsing_repository.dart';
import '../../data/services/receipt_camera.dart';
import '../../l10n/l10n.dart';
import '../view_models/receipt/receipt_scan_view_model.dart';
import '../widgets/accent_button.dart';
import '../widgets/raised_icon.dart';
import '../widgets/toast.dart';
import 'receipt_scan_format.dart';

/// The camera for a receipt: a live picture, a shutter, a lamp, up to three shots (a long
/// receipt is shot in parts) shown as small pictures that can be taken back, a button to
/// choose photos from the gallery at the bottom right, and "Read" once there is a photo.
/// The third shot reads by itself. While Gemini reads, the screen shows a spinner over the
/// shots; when the review is ready the screen closes with `true`. Photos live in memory
/// only.
class ReceiptCameraScreen extends ConsumerStatefulWidget {
  const ReceiptCameraScreen({super.key});

  @override
  ConsumerState<ReceiptCameraScreen> createState() =>
      _ReceiptCameraScreenState();
}

class _ReceiptCameraScreenState extends ConsumerState<ReceiptCameraScreen>
    with WidgetsBindingObserver {
  CameraSession? _session;
  bool _opening = true;
  bool _torch = false;
  bool _shooting = false;

  ReceiptScanViewModel get _scan => ref.read(receiptScanProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scan.warmUp();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final result = await ref.read(receiptCameraProvider).open();
    if (!mounted) {
      if (result case Ok(:final value)) await value.close();
      return;
    }
    switch (result) {
      case Ok(:final value):
        setState(() {
          _session = value;
          _opening = false;
        });
      case Failure(:final error):
        setState(() => _opening = false);
        // The gallery still works: the screen stays, with the reason as a toast.
        showToast(
          context,
          error == CameraError.denied
              ? context.l10n.cameraDenied
              : context.l10n.cameraUnavailable,
        );
    }
  }

  /// The camera is released while the app is away and opened again on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final old = _session;
      if (old != null) {
        setState(() {
          _session = null;
          _torch = false;
        });
        old.close();
      }
    } else if (state == AppLifecycleState.resumed &&
        _session == null &&
        !_opening) {
      _opening = true;
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.close();
    super.dispose();
  }

  Future<void> _shoot() async {
    final session = _session;
    if (session == null ||
        _shooting ||
        !ref.read(receiptScanProvider).canAddPhoto) {
      return;
    }
    setState(() => _shooting = true);
    final shot = await session.capture();
    if (!mounted) return;
    setState(() => _shooting = false);
    if (shot case Ok(:final value)) {
      _scan.addShot(value);
      await _readWhenFull();
    }
  }

  Future<void> _gallery() async {
    if (!ref.read(receiptScanProvider).canAddPhoto) return;
    await _scan.addFromGallery();
    if (!mounted) return;
    await _readWhenFull();
  }

  /// The last photo that fits starts the reading: nothing more can be asked of the user.
  Future<void> _readWhenFull() async {
    if (ref.read(receiptScanProvider).photos >=
        ReceiptParsingRepository.maxPhotos) {
      await _read();
    }
  }

  Future<void> _read() => _scan.read(
    language: receiptLanguage(context),
    fallbackCurrency: receiptFallbackCurrency(context),
  );

  Future<void> _toggleTorch() async {
    final session = _session;
    if (session == null) return;
    final next = !_torch;
    await session.setTorch(next);
    if (mounted) setState(() => _torch = next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final scan = ref.watch(receiptScanProvider);
    ref.listen(receiptScanProvider.select((s) => s.reviewReady), (_, ready) {
      if (ready) Navigator.of(context).pop(true);
    });
    final photos = _scan.photos;
    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: _session != null
                ? _session!.preview(onFocus: (_) {})
                : Center(
                    child: _opening
                        ? const SizedBox.shrink()
                        : Icon(
                            Icons.no_photography_outlined,
                            size: 48,
                            color: t.muted,
                          ),
                  ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      RaisedIcon(
                        key: const Key('cameraClose'),
                        label: l10n.closeCamera,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      if (_session != null)
                        RaisedIcon(
                          key: const Key('cameraTorch'),
                          label: l10n.cameraLamp,
                          onPressed: _toggleTorch,
                          child: Icon(
                            _torch ? Icons.flash_on : Icons.flash_off,
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (photos.isNotEmpty && !scan.busy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AccentButton(
                      buttonKey: const Key('cameraRead'),
                      label: l10n.readReceipt,
                      onPressed: _read,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(t.gutter, 0, t.gutter, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _Thumbs(
                            photos: photos,
                            enabled: !scan.busy,
                            onRemove: _scan.removePhoto,
                          ),
                        ),
                      ),
                      _Shutter(
                        key: const Key('cameraShutter'),
                        label: l10n.cameraShoot,
                        onPressed:
                            _session == null || !scan.canAddPhoto || _shooting
                            ? null
                            : _shoot,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: RaisedIcon(
                            key: const Key('cameraGallery'),
                            label: l10n.cameraGallery,
                            onPressed: scan.canAddPhoto ? _gallery : null,
                            child: const Icon(Icons.photo_library_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (scan.busy)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: t.background.withValues(alpha: 0.7),
                  child: const Center(
                    child: CircularProgressIndicator(key: Key('cameraBusy')),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The big round shutter: a ring with a disc in it.
class _Shutter extends StatelessWidget {
  const _Shutter({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.text, width: 3),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: t.text, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shots taken so far, small; a tap takes one back.
class _Thumbs extends StatelessWidget {
  const _Thumbs({
    required this.photos,
    required this.enabled,
    required this.onRemove,
  });

  final List<Uint8List> photos;
  final bool enabled;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < photos.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              key: ValueKey('thumb-$i'),
              onTap: enabled ? () => onRemove(i) : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(t.radiusChip),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Image.memory(
                        photos[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(color: t.tint),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.close, size: 14, color: t.text),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
