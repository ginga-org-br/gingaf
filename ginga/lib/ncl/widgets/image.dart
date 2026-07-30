import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../ginga_src_resolver.dart';
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
    var uriStr = GingaSrcResolver.resolveUri(widget.src);
    if (uriStr.isEmpty) {
      return const SizedBox.shrink();
    }
    final parsedUri = Uri.tryParse(uriStr);
    final isNetwork = kIsWeb ||
        (parsedUri != null &&
            (parsedUri.scheme == 'http' ||
                parsedUri.scheme == 'https' ||
                parsedUri.scheme == 'data' ||
                parsedUri.scheme == 'blob'));
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
          (parsedUri != null && parsedUri.isScheme('file')) ? parsedUri.toFilePath() : uriStr;
      return Image.file(
        File(localPath),
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
