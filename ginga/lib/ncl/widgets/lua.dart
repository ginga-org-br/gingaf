import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart';

import '../ncl_app.dart';

class LuaWidget extends MediaWidget {
  const LuaWidget({
    super.key,
    required super.src,
    super.media,
  });

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
  }

  bool _scriptRan = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scriptRan) {
      _scriptRan = true;
      _runScript();
    }
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

abstract class DrawCommand {
  Paint get paint;
  void draw(Canvas canvas);
}

class DrawRectCommand extends DrawCommand {
  final Rect rect;
  @override
  final Paint paint;
  DrawRectCommand(this.rect, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawRect(rect, paint);
  }
}

class DrawLineCommand extends DrawCommand {
  final Offset p1;
  final Offset p2;
  @override
  final Paint paint;
  DrawLineCommand(this.p1, this.p2, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawLine(p1, p2, paint);
  }
}

class DrawRoundRectCommand extends DrawCommand {
  final RRect rrect;
  @override
  final Paint paint;
  DrawRoundRectCommand(this.rrect, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawRRect(rrect, paint);
  }
}

class DrawPolygonCommand extends DrawCommand {
  final List<Offset> points;
  @override
  final Paint paint;
  DrawPolygonCommand(this.points, this.paint);

  @override
  void draw(Canvas canvas) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}

class DrawEllipseCommand extends DrawCommand {
  final Rect rect;
  @override
  final Paint paint;
  DrawEllipseCommand(this.rect, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawOval(rect, paint);
  }
}

class DrawTextCommand extends DrawCommand {
  final String text;
  final Offset offset;
  final Color color;
  DrawTextCommand(this.text, this.offset, this.color);

  @override
  Paint get paint => Paint()..color = color;

  @override
  void draw(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 14.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }
}

class DrawTextRectCommand extends DrawCommand {
  final String text;
  final Rect rect;
  final Color color;
  final String halign;
  final String valign;
  DrawTextRectCommand(
      this.text, this.rect, this.color, this.halign, this.valign);

  @override
  Paint get paint => Paint()..color = color;

  @override
  void draw(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 14.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);

    double dx = rect.left;
    if (halign == 'center') {
      dx += (rect.width - textPainter.width) / 2;
    } else if (halign == 'right') {
      dx += rect.width - textPainter.width;
    }

    double dy = rect.top;
    if (valign == 'center') {
      dy += (rect.height - textPainter.height) / 2;
    } else if (valign == 'bottom') {
      dy += rect.height - textPainter.height;
    }

    textPainter.paint(canvas, Offset(dx, dy));
  }
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
    commands.add(DrawRectCommand(Rect.fromLTWH(x, y, w, h), _buildPaint(mode)));
    onUpdate?.call();
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) {
    final paint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    commands.add(DrawLineCommand(Offset(x1, y1), Offset(x2, y2), paint));
    onUpdate?.call();
  }

  @override
  void drawRoundRect(String mode, double x, double y, double w, double h,
      double rx, double ry) {
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), Radius.elliptical(rx, ry));
    commands.add(DrawRoundRectCommand(rrect, _buildPaint(mode)));
    onUpdate?.call();
  }

  @override
  void drawPolygon(List<double> points) {
    final List<Offset> offsets = [];
    for (int i = 0; i < points.length - 1; i += 2) {
      offsets.add(Offset(points[i], points[i + 1]));
    }
    commands.add(DrawPolygonCommand(offsets, _buildPaint('fill')));
    onUpdate?.call();
  }

  @override
  void drawEllipse(String mode, double x, double y, double w, double h) {
    commands
        .add(DrawEllipseCommand(Rect.fromLTWH(x, y, w, h), _buildPaint(mode)));
    onUpdate?.call();
  }

  @override
  void drawText(String text, double x, double y) {
    commands.add(DrawTextCommand(text, Offset(x, y), currentColor));
    onUpdate?.call();
  }

  @override
  void drawTextRect(String text, double x, double y, double w, double h,
      String halign, String valign) {
    commands.add(DrawTextRectCommand(
        text, Rect.fromLTWH(x, y, w, h), currentColor, halign, valign));
    onUpdate?.call();
  }

  @override
  void clear() {
    commands.clear();
    onUpdate?.call();
  }

  @override
  void flush() {
    onUpdate?.call();
  }

  Paint _buildPaint(String mode) {
    final paint = Paint()..color = currentColor;
    if (mode == 'fill') {
      paint.style = PaintingStyle.fill;
    } else {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
    }
    return paint;
  }
}

class _LuaPainter extends CustomPainter {
  final List<DrawCommand> cmds;
  _LuaPainter(List<DrawCommand> original) : cmds = List.of(original);

  @override
  void paint(Canvas canvas, Size size) {
    if (cmds.isEmpty) return;
    for (var cmd in cmds) {
      cmd.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _LuaPainter oldDelegate) => true;
}
