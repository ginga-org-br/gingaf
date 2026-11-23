import 'package:http/http.dart' as http;

const String ssdpSearchTarget =
    'urn:schemas-sbtvd-org:service:TV3.0WebServices:1';
const String ssdpMulticastAddress = '239.255.255.250';
const int ssdpDefaultPort = 1900;

class SsdpDiscoveredReceiver {
  final String location;
  final String baseUrl;
  final String? secureBaseUrl;
  final String? pairingMethods;
  final String? brandName;
  final String? model;
  final String? friendlyName;
  final String? usn;

  const SsdpDiscoveredReceiver({
    required this.location,
    required this.baseUrl,
    this.secureBaseUrl,
    this.pairingMethods,
    this.brandName,
    this.model,
    this.friendlyName,
    this.usn,
  });

  String get httpBaseUrl =>
      baseUrl.startsWith('http://') || baseUrl.startsWith('https://')
          ? baseUrl
          : 'http://$baseUrl';
}

class SsdpServer {
  final String locationUrl;
  final int port;
  final String usn;
  final Duration announceInterval;
  bool get isRunning => false;
  int get boundPort => port;

  SsdpServer({
    required this.locationUrl,
    this.port = ssdpDefaultPort,
    this.usn = 'uuid:gingaf-tv30-receiver',
    this.announceInterval = const Duration(seconds: 10),
  });

  void announceAlive() {}
  void announceByebye() {}
  Future<void> start() async {}
  Future<void> stop() async {}
}

class SsdpClient {
  static Future<List<SsdpDiscoveredReceiver>> discover({
    int port = ssdpDefaultPort,
    Duration timeout = const Duration(seconds: 2),
    String searchTarget = ssdpSearchTarget,
    http.Client? httpClient,
  }) async {
    return const [];
  }
}
