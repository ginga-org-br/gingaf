import 'dart:io';

import 'package:flutter/material.dart';

import 'ncl_media_widget.dart';

class ImageWidget extends MediaWidget {
  ImageWidget({
    super.key,
    required String src,
    super.media,
  }) : super(src: src);

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
    final uriStr = widget.uri.toString();
    if (uriStr.isEmpty) {
      return const SizedBox.shrink();
    }
    final isNetwork =
        widget.uri.scheme == 'http' || widget.uri.scheme == 'https';
    if (isNetwork) {
      return Image.network(
        uriStr,
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
      final localPath =
          widget.uri.isScheme('file') ? widget.uri.toFilePath() : uriStr;
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
