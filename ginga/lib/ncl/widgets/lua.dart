import 'package:flutter/material.dart';
import 'package:ncl_doc/ncl_document.dart' hide State;
import '../ncl_app.dart';
import 'ncl_media_widget.dart';

class LuaWidget extends MediaWidget {
  const LuaWidget({super.key, required super.uri, super.media});

  @override
  State<LuaWidget> createState() => LuaWidgetState();
}

class LuaWidgetState extends MediaState<LuaWidget> {
  late NCLua _engine;
  final CanvasState canvasState = CanvasState();

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
    _engine = NCLua(delegate: canvasState);

    _engine.settingsProvider = (name) {
      final appState = context.findAncestorStateOfType<NCLAppState>();
      final doc = appState?.nclDocument;
      if (doc != null) {
        return doc.getPropertyValue(doc.getSettings(), name);
      }
      return null;
    };

    _engine.getPersistentVar = (name) {
      final appState = context.findAncestorStateOfType<NCLAppState>();
      return appState?.persistentVars[name];
    };

    _engine.setPersistentVar = (name, value) {
      final appState = context.findAncestorStateOfType<NCLAppState>();
      if (appState != null) {
        appState.persistentVars[name] = value;
      }
    };

    canvasState.onUpdate = () {
      if (mounted) setState(() {});
    };

    _runScript();
  }

  Future<void> _runScript() async {
    canvasState.reset();
    try {
      final script = await loadContent(widget.uri);
      _engine.execute(script);
    } catch (e) {
      debugPrint("Lua Runtime Error: $e");
    }
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LuaPainter(canvasState.commands),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class DrawCommand {
  final Rect rect;
  final Paint paint;
  DrawCommand(this.rect, this.paint);
}

class CanvasState implements NCLCanvasDelegate {
  final List<DrawCommand> commands = [];
  Color currentColor = Colors.black;
  VoidCallback? onUpdate;

  void reset() {
    commands.clear();
    currentColor = Colors.black;
  }

  @override
  void attrColor(int r, int g, int b, int a) {
    currentColor = Color.fromARGB(a, r, g, b);
  }

  @override
  void drawRect(String mode, double x, double y, double w, double h) {
    final paint = Paint()..color = currentColor;
    if (mode == 'fill') {
      paint.style = PaintingStyle.fill;
    } else {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
    }
    commands.add(DrawCommand(Rect.fromLTWH(x, y, w, h), paint));
    onUpdate?.call();
  }
}

class _LuaPainter extends CustomPainter {
  final List<DrawCommand> cmds;
  _LuaPainter(List<DrawCommand> original) : cmds = List.of(original);

  @override
  void paint(Canvas canvas, Size size) {
    if (cmds.isEmpty) return;
    for (var cmd in cmds) {
      canvas.drawRect(cmd.rect, cmd.paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LuaPainter oldDelegate) => true;
}
