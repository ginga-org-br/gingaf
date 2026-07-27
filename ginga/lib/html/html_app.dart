import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gingaf/ccws/ccws.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/ncl/widgets/ncl_media_widget.dart';
import 'package:logging/logging.dart';
import 'package:webview_all/webview_all.dart';

final _logger = Logger('ginga-html');

class HTMLApp extends MediaWidget {
  final Map<String, void Function(JavaScriptMessage)>? javaScriptChannels;
  final CCWS? ccws;
  final GingaConfig? config;

  const HTMLApp(
      {super.key,
      required super.uri,
      super.media,
      this.javaScriptChannels,
      this.ccws,
      this.config});

  @override
  State<HTMLApp> createState() => HTMLAppState();
}

class HTMLAppState extends MediaState<HTMLApp> {
  late final WebViewController _controller;
  bool _initialized = false;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _logger.info("Starting HTML application: ${widget.uri}");
    _controller = WebViewController()
      ..setBackgroundColor(const Color(0x00000000));

    if (!kIsWeb) {
      widget.javaScriptChannels?.forEach((name, callback) {
        _controller.addJavaScriptChannel(name, onMessageReceived: callback);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _loadHTML();
    }
  }

  Future<void> _loadHTML() async {
    try {
      String content = await loadContent(widget.uri);

      if (widget.ccws != null || (widget.config?.enableCCWS ?? false)) {
        if (widget.ccws != null) {
          content = widget.ccws!.injectCcwsFetch(content);
        }
      }

      await _controller.loadHtmlString(content);
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      _logger.severe("Error loading ${widget.uri}: $e");
      final errorHtml = """
        <!DOCTYPE html>
        <html>
        <body>
          <h1>Ginga HTML Runtime</h1>
          <p>Error loading: ${widget.uri}</p>
          <p style='color: red;'>$e</p>
        </body>
        </html>
      """;
      try {
        await _controller.loadHtmlString(errorHtml);
      } catch (_) {}
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  void dispose() {
    _logger.info("Stopping HTML application: ${widget.uri}");
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: _initialized
            ? WebViewWidget(controller: _controller)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
