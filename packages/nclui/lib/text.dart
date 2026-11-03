import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart';

import 'base_widget.dart';

class TextWidget extends BaseWidget {
  final bool embedded;
  final TextAlign textAlign;
  final int? maxLines;

  const TextWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
    super.gingacc,
    this.embedded = false,
    this.textAlign = TextAlign.left,
    this.maxLines,
  });

  @override
  State<TextWidget> createState() => TextWidgetState();
}

class TextWidgetState extends MediaState<TextWidget> {
  String _content = '';
  Color? _fontColor;
  double? _fontSize;

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
    _loadText();
  }

  @override
  void didUpdateWidget(covariant TextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src || oldWidget.media != widget.media) {
      _loadText();
    }
  }

  @override
  void parseProperties([Media? targetMedia]) {
    super.parseProperties(targetMedia);
    final m = targetMedia ?? media;
    String? rawColor = m?.rawAttributes['fontColor'];
    String? rawSize = m?.rawAttributes['fontSize'];

    if (m != null) {
      for (final prop in m.getProperties()) {
        if (prop.name == 'fontColor' || prop.name == 'color') {
          rawColor = prop.value;
        } else if (prop.name == 'fontSize') {
          rawSize = prop.value;
        }
      }
      final desc = document?.getDescriptorForMedia(m);
      if (desc != null) {
        for (final dp in desc.descriptorParams) {
          if ((dp.name == 'fontColor' || dp.name == 'color') &&
              rawColor == null) {
            rawColor = dp.value;
          } else if (dp.name == 'fontSize' && rawSize == null) {
            rawSize = dp.value;
          }
        }
      }
    }

    _fontColor = _parseFontColor(rawColor);
    if (rawSize != null && rawSize.isNotEmpty) {
      final cleaned = rawSize.replaceAll('px', '').replaceAll('pt', '').trim();
      _fontSize = double.tryParse(cleaned);
    } else {
      _fontSize = null;
    }
  }

  Color? _parseFontColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('#')) {
      final hex = raw.substring(1);
      if (hex.length == 6) {
        final v = int.tryParse('FF$hex', radix: 16);
        if (v != null) return Color(v);
      } else if (hex.length == 8) {
        final v = int.tryParse(hex, radix: 16);
        if (v != null) return Color(v);
      }
    }
    switch (raw.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'gray':
      case 'grey':
        return Colors.grey;
      default:
        return null;
    }
  }

  void _loadText() {
    final rawSrc = widget.src.trim();
    if (rawSrc.isEmpty) {
      _content = '';
      return;
    }
    final syncLoaded = widget.privateBase.loadContentSync(rawSrc);
    if (syncLoaded != null) {
      _content = syncLoaded;
      return;
    }
    _content = rawSrc;
    widget.privateBase.loadContent(rawSrc).then((loaded) {
      if (mounted && loaded != null && loaded != _content) {
        setState(() {
          _content = loaded;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return buildWidgetContent(context);
    }
    return super.build(context);
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return Text(
      _content,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        color: _fontColor ?? Colors.white,
        fontSize: _fontSize,
      ),
    );
  }
}
