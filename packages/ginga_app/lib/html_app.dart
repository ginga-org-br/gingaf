import 'base_ginga_app.dart';

class HtmlApp extends BaseGingaApp {
  String get src => appSrc;

  Uri? get baseUri => appContext.baseUri;

  HtmlApp({
    super.applicationId = 'html_app',
    super.gingacc,
    String? appSrc,
    String? src,
    super.baseUri,
  }) : super(
          appSrc: (appSrc ?? src) ?? '',
        );
}
