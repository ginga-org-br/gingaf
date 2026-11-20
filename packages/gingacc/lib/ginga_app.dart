import 'gingacc.dart';

class GingaApp {
  final String applicationId;
  final String appSrc;
  final GingaCC gingacc;
  final GingaAppContext appContext;

  String get appContextId => appContext.appContextId;

  GingaApp({
    String? applicationId,
    required String appSrc,
    GingaCC? gingacc,
    Uri? baseUri,
  }) : this._(
          applicationId: applicationId ?? appSrc,
          appSrc: appSrc,
          gingacc: gingacc ?? GingaCC(),
          baseUri: baseUri,
        );

  GingaApp._({
    required this.applicationId,
    required this.appSrc,
    required this.gingacc,
    Uri? baseUri,
  }) : appContext = gingacc.getAppContext(
          appContextId: applicationId,
          baseUri: baseUri,
        );
}
