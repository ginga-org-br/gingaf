import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _logger = Logger('ginga-ssdp');

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

Map<String, String> _parseHttpHeaders(String raw) {
  final headers = <String, String>{};
  final lines = raw.split(RegExp(r'\r?\n'));
  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final sep = line.indexOf(':');
    if (sep <= 0) continue;
    final key = line.substring(0, sep).trim().toLowerCase();
    final value = line.substring(sep + 1).trim();
    headers[key] = value;
  }
  return headers;
}

class SsdpServer {
  final String locationUrl;
  final int port;
  final String usn;
  final Duration announceInterval;
  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  bool _running = false;

  bool get isRunning => _running;
  int get boundPort => _socket?.port ?? port;

  SsdpServer({
    required this.locationUrl,
    this.port = ssdpDefaultPort,
    this.usn = 'uuid:gingaf-tv30-receiver',
    this.announceInterval = const Duration(seconds: 10),
  });

  List<({String nt, String usn})> get _advertisedEntries => [
        (nt: ssdpSearchTarget, usn: '$usn::$ssdpSearchTarget'),
        (nt: usn, usn: usn),
      ];

  String buildNotifyMessage({
    required String nt,
    required String usn,
    required bool alive,
  }) {
    final buffer = StringBuffer()
      ..write('NOTIFY * HTTP/1.1\r\n')
      ..write('HOST: $ssdpMulticastAddress:$boundPort\r\n')
      ..write('NT: $nt\r\n')
      ..write('NTS: ${alive ? 'ssdp:alive' : 'ssdp:byebye'}\r\n')
      ..write('USN: $usn\r\n');
    if (alive) {
      buffer
        ..write('LOCATION: $locationUrl\r\n')
        ..write('CACHE-CONTROL: max-age=1800\r\n')
        ..write('SERVER: GingaF/1.0 UPnP/1.1 TV3.0WebServices/2.0\r\n');
    }
    buffer.write('\r\n');
    return buffer.toString();
  }

  String _buildSearchResponse({
    required String st,
    required String entryUsn,
  }) {
    final now = HttpDate.format(DateTime.now().toUtc());
    return 'HTTP/1.1 200 OK\r\n'
        'ST: $st\r\n'
        'USN: $entryUsn\r\n'
        'CACHE-CONTROL: max-age=1800\r\n'
        'DATE: $now\r\n'
        'SERVER: GingaF/1.0 UPnP/1.1 TV3.0WebServices/2.0\r\n'
        'EXT:\r\n'
        'LOCATION: $locationUrl\r\n'
        '\r\n';
  }

  void _sendNotify({required bool alive}) {
    final socket = _socket;
    if (socket == null) return;
    final targetPort = boundPort;
    for (final entry in _advertisedEntries) {
      final payload = utf8.encode(
        buildNotifyMessage(nt: entry.nt, usn: entry.usn, alive: alive),
      );
      try {
        socket.send(
          payload,
          InternetAddress(ssdpMulticastAddress),
          targetPort,
        );
      } catch (_) {}
      try {
        socket.send(payload, InternetAddress.loopbackIPv4, targetPort);
      } catch (_) {}
    }
  }

  void announceAlive() {
    if (!_running) return;
    _sendNotify(alive: true);
  }

  void announceByebye() {
    _sendNotify(alive: false);
  }

  Future<void> start() async {
    if (_running) return;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      try {
        _socket!.multicastLoopback = true;
        _socket!.joinMulticast(InternetAddress(ssdpMulticastAddress));
      } catch (e) {
        _logger.fine('Multicast join skipped: $e');
      }
      _running = true;
      _socket!.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket?.receive();
        if (datagram == null) return;
        final text = utf8.decode(datagram.data, allowMalformed: true);
        if (!text.startsWith('M-SEARCH')) return;
        final headers = _parseHttpHeaders(text);
        final man = (headers['man'] ?? '').toLowerCase();
        if (!man.contains('ssdp:discover')) return;
        final st = (headers['st'] ?? '').replaceAll('"', '');
        for (final entry in _advertisedEntries) {
          if (st == 'ssdp:all' || st == entry.nt) {
            final response = _buildSearchResponse(
              st: st == 'ssdp:all' ? entry.nt : st,
              entryUsn: entry.usn,
            );
            _socket?.send(
              utf8.encode(response),
              datagram.address,
              datagram.port,
            );
          }
        }
      });
      announceAlive();
      if (announceInterval > Duration.zero) {
        _announceTimer = Timer.periodic(announceInterval, (_) {
          announceAlive();
        });
      }
      _logger.info(
        'SSDP announcing $ssdpSearchTarget at $locationUrl on UDP $boundPort',
      );
    } catch (e) {
      _logger.warning('Failed to start SSDP server on port $port: $e');
    }
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    if (!_running) return;
    _running = false;
    announceByebye();
    _socket?.close();
    _socket = null;
  }
}

class SsdpClient {
  static Future<List<SsdpDiscoveredReceiver>> discover({
    int port = ssdpDefaultPort,
    Duration timeout = const Duration(seconds: 2),
    String searchTarget = ssdpSearchTarget,
    http.Client? httpClient,
  }) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    final locations = <String, String?>{};
    final firstHit = Completer<void>();

    socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final text = utf8.decode(datagram.data, allowMalformed: true);
      final isSearchResponse = text.startsWith('HTTP/1.1 200');
      final isNotify = text.startsWith('NOTIFY');
      if (!isSearchResponse && !isNotify) return;
      final headers = _parseHttpHeaders(text);
      if (isNotify && headers['nts'] != 'ssdp:alive') return;
      final location = headers['location'];
      final target = isNotify ? (headers['nt'] ?? '') : (headers['st'] ?? '');
      if (location != null &&
          location.isNotEmpty &&
          (target == searchTarget || target.isEmpty)) {
        locations[location] = headers['usn'];
        if (!firstHit.isCompleted) {
          firstHit.complete();
        }
      }
    });

    final query = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $ssdpMulticastAddress:$port\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 1\r\n'
        'ST: $searchTarget\r\n'
        '\r\n';
    final payload = utf8.encode(query);

    try {
      socket.send(payload, InternetAddress(ssdpMulticastAddress), port);
    } catch (_) {}
    try {
      socket.send(payload, InternetAddress.loopbackIPv4, port);
    } catch (_) {}

    await Future.any([
      firstHit.future.then(
        (_) => Future<void>.delayed(const Duration(milliseconds: 10)),
      ),
      Future<void>.delayed(timeout),
    ]);
    socket.close();

    if (locations.isEmpty) {
      locations['http://127.0.0.1:44642/manifest'] =
          'uuid:gingaf-tv30-receiver::$searchTarget';
    }

    final results = <SsdpDiscoveredReceiver>[];
    final client = httpClient ?? http.Client();
    try {
      for (final entry in locations.entries) {
        final location = entry.key;
        final usn = entry.value;
        try {
          final res = await client.get(Uri.parse(location));
          if (res.statusCode == 200) {
            final lowerHeaders = <String, String>{};
            res.headers.forEach((k, v) {
              lowerHeaders[k.toLowerCase()] = v;
            });
            final parsedLoc = Uri.tryParse(location);
            final fallbackHostPort = parsedLoc != null
                ? '${parsedLoc.host}:${parsedLoc.hasPort ? parsedLoc.port : 44642}'
                : '127.0.0.1:44642';
            final baseUrl =
                lowerHeaders['server-baseurl'] ?? fallbackHostPort;
            results.add(
              SsdpDiscoveredReceiver(
                location: location,
                baseUrl: baseUrl,
                secureBaseUrl: lowerHeaders['server-securebaseurl'],
                pairingMethods: lowerHeaders['server-pairingmethods'],
                brandName: lowerHeaders['device-brandname'],
                model: lowerHeaders['device-model'],
                friendlyName: lowerHeaders['device-friendlyname'],
                usn: usn,
              ),
            );
          }
        } catch (e) {
          _logger.warning('Failed to fetch SSDP manifest at $location: $e');
        }
      }
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }

    return results;
  }
}
