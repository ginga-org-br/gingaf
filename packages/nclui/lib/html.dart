import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gingacc/ccws.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:logging/logging.dart';
import 'package:webview_all/webview_all.dart';

import 'base_widget.dart';

final _logger = Logger('ginga-html');

class HtmlWidget extends BaseWidget {
  final Map<String, void Function(JavaScriptMessage)>? javaScriptChannels;
  final CCWS? ccws;
  final GingaConfig config;

  HtmlWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
    this.javaScriptChannels,
    this.ccws,
    GingaConfig? config,
  }) : config = config ?? GingaConfig();

  @override
  State<HtmlWidget> createState() => HtmlWidgetState();
}

class HtmlWidgetState extends MediaState<HtmlWidget> {
  WebViewController? _controller;
  bool _initialized = false;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    _logger.info("Starting HTML application: ${widget.src}");
    try {
      _controller = WebViewController()
        ..setBackgroundColor(const Color(0x00000000));

      if (!kIsWeb) {
        widget.javaScriptChannels?.forEach((name, callback) {
          _controller?.addJavaScriptChannel(name, onMessageReceived: callback);
        });
      }
    } catch (e) {
      _logger.warning("Could not initialize WebViewController: $e");
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
    if (_controller == null) return;
    try {
      String content = await loadContent(widget.src) ?? '';

      if (widget.ccws != null && widget.config.enableCCWS) {
        content = widget.ccws!.injectCcwsFetch(content);
      }

      await _controller!.loadHtmlString(content);
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      _logger.severe("Error loading ${widget.src}: $e");
      final errorHtml = """
        <!DOCTYPE html>
        <html>
        <body>
          <h1>Ginga HTML Runtime</h1>
          <p>Error loading: ${widget.src}</p>
          <p style='color: red;'>$e</p>
        </body>
        </html>
      """;
      try {
        await _controller?.loadHtmlString(errorHtml);
      } catch (_) {}
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  void dispose() {
    _logger.info("Stopping HTML application: ${widget.src}");
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (_controller == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Text(
            "HtmlWidget",
            style: TextStyle(color: Colors.black),
          ),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: _initialized
          ? WebViewWidget(controller: _controller!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
