import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/base_widget.dart';
import 'package:nclui/nclui_plugins.dart';

import 'plugin_base.dart';

class SrtCue {
  final int index;
  final Duration start;
  final Duration end;
  final String text;

  const SrtCue({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });

  bool isActiveAt(Duration position) => position >= start && position <= end;
}

List<SrtCue> parseSrtContent(String srtText) {
  final cues = <SrtCue>[];
  final blocks =
      srtText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n\n');

  for (final block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.length < 2) continue;

    final index = int.tryParse(lines[0].trim());
    final timeLine = index != null ? lines[1].trim() : lines[0].trim();
    final textLines = index != null ? lines.sublist(2) : lines.sublist(1);

    final timeParts = timeLine.split('-->');
    if (timeParts.length != 2) continue;

    final start = _parseSrtTimestamp(timeParts[0].trim());
    final end = _parseSrtTimestamp(timeParts[1].trim());

    if (start != null && end != null) {
      cues.add(SrtCue(
        index: index ?? (cues.length + 1),
        start: start,
        end: end,
        text: textLines.join('\n').trim(),
      ));
    }
  }

  return cues;
}

Duration? _parseSrtTimestamp(String timestamp) {
  try {
    final parts = timestamp.split(':');
    if (parts.length != 3) return null;
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final secParts = parts[2].split(RegExp('[,.]'));
    final seconds = int.parse(secParts[0]);
    final millis = secParts.length > 1
        ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
        : 0;
    return Duration(
        hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  } catch (_) {
    return null;
  }
}

class SrtMediaPlugin implements NclMediaPlugin, NclTickPlugin, PluginBase {
  @override
  PluginType get type => PluginType.experimental;

  Duration currentPosition = Duration.zero;

  @override
  void onTick(Duration elapsed, NclDocument document) {
    currentPosition += elapsed;
  }

  @override
  bool canHandle(String src, String? mimeType) {
    final lower = src.toLowerCase();
    return lower.endsWith('.srt') ||
        mimeType == 'text/srt' ||
        mimeType == 'application/x-subrip';
  }

  @override
  Widget buildWidget({
    Key? key,
    required String src,
    String? mimeType,
    Media? media,
    NclDocument? document,
    FocusNode? focusNode,
  }) {
    return SrtWidget(
      key: key,
      src: src,
      media: media,
      document: document,
    );
  }
}

class SrtWidget extends BaseWidget {
  const SrtWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
  });

  @override
  State<SrtWidget> createState() => _SrtWidgetState();
}

class _SrtWidgetState extends MediaState<SrtWidget> {
  List<SrtCue> _cues = [];
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String _activeText = '';

  @override
  void initState() {
    super.initState();
    _loadSrt();
  }

  Future<void> _loadSrt() async {
    final content = await widget.privateBase.loadContent(widget.src);
    if (content != null && mounted) {
      setState(() {
        _cues = parseSrtContent(content);
      });
      _startPlayback();
    }
  }

  void _startPlayback() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _elapsed += const Duration(milliseconds: 200);
      final active = _cues
          .where((c) => c.isActiveAt(_elapsed))
          .map((c) => c.text)
          .join('\n');
      if (active != _activeText) {
        setState(() {
          _activeText = active;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (_activeText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          _activeText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
