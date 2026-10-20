import 'package:gingacc/gingacc.dart';

class HtmlApp extends GingaApp {
  String get src => appSrc;

  Uri? get baseUri => privateBase.baseUri;

  HtmlApp({
    super.applicationId = 'html_app',
    super.gingacc,
    String? appSrc,
    String? src,
    super.baseUri,
  }) : super(appSrc: (appSrc ?? src) ?? '');
}
