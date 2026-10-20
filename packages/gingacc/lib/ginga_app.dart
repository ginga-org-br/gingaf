import 'gingacc.dart';

class GingaApp {
  final String applicationId;
  final String appSrc;
  final GingaCC gingacc;
  final GingaAppPrivateBase privateBase;

  GingaApp({
    String? applicationId,
    required this.appSrc,
    GingaCC? gingacc,
    Uri? baseUri,
  })  : applicationId = applicationId ?? appSrc,
        gingacc = gingacc ?? GingaCC(),
        privateBase = (gingacc ?? GingaCC()).getPrivateBase(
          applicationId: applicationId ?? appSrc,
          baseUri: baseUri,
        );
}
