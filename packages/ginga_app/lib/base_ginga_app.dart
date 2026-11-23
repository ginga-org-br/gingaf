import 'package:gingacc/gingacc.dart';

class BaseGingaApp {
  final String applicationId;
  final String appSrc;
  final GingaCC gingacc;
  final GingaAppContext appContext;

  String get appContextId => appContext.appContextId;

  BaseGingaApp({
    String? applicationId,
    required String appSrc,
    GingaCC? gingacc,
    GingaAppContext? appContext,
    Uri? baseUri,
  }) : this._(
          resolvedId:
              applicationId ?? (appSrc.isNotEmpty ? appSrc : 'ginga_app'),
          appSrc: appSrc,
          gingacc: gingacc ?? GingaCC(),
          appContext: appContext,
          baseUri: baseUri,
        );

  BaseGingaApp._({
    required String resolvedId,
    required this.appSrc,
    required this.gingacc,
    GingaAppContext? appContext,
    Uri? baseUri,
  })  : applicationId = resolvedId,
        appContext = appContext ??
            gingacc.getAppContext(
              appContextId: resolvedId,
              baseUri: baseUri,
            );
}

