import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Platform-safe image display widget.
/// Uses XFile.readAsBytes() which works on ALL platforms (web + mobile).
/// Avoids dart:io entirely — safe for web compilation.
class XFileImage extends StatefulWidget {
  final XFile file;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const XFileImage({
    super.key,
    required this.file,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<XFileImage> createState() => _XFileImageState();
}

class _XFileImageState extends State<XFileImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(XFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadBytes();
    }
  }

  Future<void> _loadBytes() async {
    try {
      final bytes = await widget.file.readAsBytes();
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_error) {
      child = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    } else if (_loading || _bytes == null) {
      child = SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      child = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }
}
