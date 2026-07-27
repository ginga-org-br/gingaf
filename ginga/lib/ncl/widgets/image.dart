import 'dart:io';

import 'package:flutter/material.dart';

import 'ncl_media_widget.dart';

class ImageWidget extends MediaWidget {
  const ImageWidget({super.key, required super.uri, super.media});

  @override
  State<ImageWidget> createState() => ImageWidgetState();
}

class ImageWidgetState extends MediaState<ImageWidget> {
  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (widget.uri.isEmpty) {
      return const SizedBox.shrink();
    }
    final isNetwork =
        widget.uri.startsWith('http://') || widget.uri.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        widget.uri,
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
              child: Icon(Icons.error, color: Colors.red, size: 50));
        },
      );
    } else {
      String localPath = widget.uri;
      if (localPath.startsWith('file://')) {
        localPath = Uri.parse(localPath).toFilePath();
      }
      final file = File(localPath);
      return Image.file(
        file,
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
              child: Icon(Icons.error, color: Colors.red, size: 50));
        },
      );
    }
  }
}
