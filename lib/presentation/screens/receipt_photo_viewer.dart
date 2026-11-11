import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The photos of the receipt being checked, to compare the matches with the paper:
/// swipe between the shots, pinch to zoom. They live in memory only and are gone when
/// the review closes.
class ReceiptPhotoViewer extends StatefulWidget {
  const ReceiptPhotoViewer({super.key, required this.photos});

  final List<Uint8List> photos;

  @override
  State<ReceiptPhotoViewer> createState() => _ReceiptPhotoViewerState();
}

class _ReceiptPhotoViewerState extends State<ReceiptPhotoViewer> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final many = widget.photos.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: many ? Text('${_page + 1} / ${widget.photos.length}') : null,
      ),
      body: PageView(
        key: const Key('receiptPhotos'),
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          for (final photo in widget.photos)
            InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.memory(
                  photo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
