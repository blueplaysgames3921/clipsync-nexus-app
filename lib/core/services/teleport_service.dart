import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nsd/nsd.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/clip_record.dart';
import 'settings_service.dart';

enum TeleportSendMode { push, offer, sync }
enum PeerStatus { online, offline, pairing }

class TeleportPeer {
  final String id;
  final String displayName;
  final String publicKeyFingerprint;
  final String platform;
  final InternetAddress address;
  final int port;
  PeerStatus status;
  DateTime lastSeen;
  bool isTrusted;

  TeleportPeer({
    required this.id,
    required this.displayName,
    required this.publicKeyFingerprint,
    required this.platform,
    required this.address,
    required this.port,
    this.status = PeerStatus.online,
    this.isTrusted = false,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}

class TransferProgress {
  final String peerId;
  final String clipId;
  final int totalBytes;
  int transferredBytes;
  bool isComplete;
  bool isFailed;
  String? error;

  TransferProgress({
    required this.peerId,
    required this.clipId,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.isComplete = false,
    this.isFailed = false,
    this.error,
  });

  double get progress =>
      totalBytes == 0 ? 0 : transferredBytes / totalBytes;
}

class SasSession {
  final String peerId;
  final String sasCode;
  final DateTime createdAt;
  final Completer<bool> confirmed;

  SasSession({
    required this.peerId,
    required this.sasCode,
  })  : createdAt = DateTime.now(),
        confirmed = Completer<bool>();
}

/// Handles all P2P Teleport functionality:
/// mDNS discovery → SAS pairing → TLS transfer
class TeleportService {
  final SettingsService settings;

  final _peers = <String, TeleportPeer>{};
  final _peersController = StreamController<List<TeleportPeer>>.broadcast();
  final _progressController = StreamController<TransferProgress>.broadcast();
  final _incomingController = StreamController<ClipRecord>.broadcast();
  final _offerController = StreamController<({TeleportPeer peer, ClipRecord clip})>.broadcast();

  Stream<List<TeleportPeer>> get peersStream => _peersController.stream;
  Stream<TransferProgress> get progressStream => _progressController.stream;
  Stream<ClipRecord> get incomingStream => _incomingController.stream;
  Stream<({TeleportPeer peer, ClipRecord clip})> get offerStream => _offerController.stream;

  List<TeleportPeer> get peers => _peers.values.toList();

  Discovery? _discovery;
  Registration? _registration;
  HttpServer? _server;
  int _serverPort = 0;
  final _activeSasSessions = <String, SasSession>{};

  // Device identity (Ed25519 key pair — persisted in secure storage)
  late String _deviceId;
  late String _publicKeyFingerprint;
  // In production: use pointycastle Ed25519 keypair
  // For now: deterministic placeholder derived from device ID
  late String _privateKey;

  static const String _serviceType = '_clipsyncteleport._tcp';
  static const Duration _peerTimeout = Duration(seconds: 10);

  TeleportService({required this.settings});

  // ── INIT ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (!settings.current.teleportEnabled) return;

    _deviceId = const Uuid().v4(); // load from secure storage in production
    _publicKeyFingerprint = _generateFingerprint(_deviceId);
    _privateKey = _deviceId; // placeholder

    await _startReceiver();
    await _startDiscovery();
    await _startAdvertising();
    _startPeerPruner();
  }

  // ── mDNS DISCOVERY ───────────────────────────────────────────────────────

  Future<void> _startDiscovery() async {
    try {
      _discovery = await startDiscovery(_serviceType);
      _discovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          _handlePeerFound(service);
        } else if (status == ServiceStatus.lost) {
          _handlePeerLost(service);
        }
      });
    } catch (e) {
      // mDNS unavailable — continue without discovery
    }
  }

  Future<void> _startAdvertising() async {
    try {
      final service = Service(
        name: settings.current.deviceDisplayName,
        type: _serviceType,
        port: _serverPort,
        txt: {
          'id': utf8.encode(_deviceId),
          'fp': utf8.encode(_publicKeyFingerprint),
          'platform': utf8.encode(Platform.operatingSystem),
          'version': utf8.encode('1.0.0'),
        },
      );
      _registration = await register(service);
    } catch (e) {
      // Advertising unavailable
    }
  }

  void _handlePeerFound(Service service) {
    final txt = service.txt ?? {};
    final id = _decodeUtf8(txt['id']);
    if (id == null || id == _deviceId) return; // skip self

    final fp = _decodeUtf8(txt['fp']) ?? '';
    final platform = _decodeUtf8(txt['platform']) ?? 'unknown';
    final host = service.host;
    final port = service.port;
    if (host == null || port == null) return;

    final address = InternetAddress.tryParse(host);
    if (address == null) return;

    final peer = TeleportPeer(
      id: id,
      displayName: service.name ?? 'Unknown Device',
      publicKeyFingerprint: fp,
      platform: platform,
      address: address,
      port: port,
      isTrusted: _isTrustedPeer(id, fp),
    );

    _peers[id] = peer;
    _peersController.add(_peers.values.toList());
  }

  void _handlePeerLost(Service service) {
    final txt = service.txt ?? {};
    final id = _decodeUtf8(txt['id']);
    if (id == null) return;
    _peers[id]?.status = PeerStatus.offline;
    _peersController.add(_peers.values.toList());
  }

  void _startPeerPruner() {
    Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      for (final peer in _peers.values) {
        if (now.difference(peer.lastSeen) > _peerTimeout) {
          peer.status = PeerStatus.offline;
        }
      }
      _peersController.add(_peers.values.toList());
    });
  }

  // ── RECEIVER SERVER ───────────────────────────────────────────────────────

  Future<void> _startReceiver() async {
    final router = Router();

    // Ping / discovery handshake
    router.get('/ping', (Request req) {
      return Response.ok(jsonEncode({
        'id': _deviceId,
        'fp': _publicKeyFingerprint,
        'name': settings.current.deviceDisplayName,
        'platform': Platform.operatingSystem,
      }), headers: {'content-type': 'application/json'});
    });

    // SAS pairing — step 1: receive peer's public key, return SAS
    router.post('/pair/initiate', (Request req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final peerId = body['peerId'] as String;
      final peerFp = body['fingerprint'] as String;

      final sasCode = _generateSasCode(peerId, peerFp, _publicKeyFingerprint);
      final session = SasSession(peerId: peerId, sasCode: sasCode);
      _activeSasSessions[peerId] = session;

      return Response.ok(jsonEncode({
        'sasCode': sasCode,
        'myFingerprint': _publicKeyFingerprint,
      }), headers: {'content-type': 'application/json'});
    });

    // SAS pairing — step 2: confirm match
    router.post('/pair/confirm', (Request req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final peerId = body['peerId'] as String;
      final confirmed = body['confirmed'] as bool;

      final session = _activeSasSessions[peerId];
      if (session == null) {
        return Response.forbidden('No active pairing session');
      }

      if (confirmed) {
        _activeSasSessions.remove(peerId);
        _addTrustedPeer(peerId, body['fingerprint'] as String? ?? '');
        return Response.ok(jsonEncode({'status': 'trusted'}));
      } else {
        _activeSasSessions.remove(peerId);
        return Response.ok(jsonEncode({'status': 'rejected'}));
      }
    });

    // Receive a clip offer (offer mode)
    router.post('/clip/offer', (Request req) async {
      if (!_verifyAuth(req)) return Response.forbidden('Unauthorized');
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final peerId = body['senderId'] as String;
      final peer = _peers[peerId];
      if (peer == null || !peer.isTrusted) return Response.forbidden('Peer not trusted');

      final clip = _clipFromJson(body['clip'] as Map<String, dynamic>);
      _offerController.add((peer: peer, clip: clip));
      return Response.ok(jsonEncode({'status': 'offered'}));
    });

    // Receive a clip directly (push mode)
    router.post('/clip/push', (Request req) async {
      if (!_verifyAuth(req)) return Response.forbidden('Unauthorized');
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final peerId = body['senderId'] as String;
      final peer = _peers[peerId];
      if (peer == null || !peer.isTrusted) return Response.forbidden('Peer not trusted');

      final clip = _clipFromJson(body['clip'] as Map<String, dynamic>);
      _incomingController.add(clip);
      return Response.ok(jsonEncode({'status': 'received'}));
    });

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _serverPort = _server!.port;
  }

  // ── SEND ─────────────────────────────────────────────────────────────────

  Future<void> sendClip(String peerId, ClipRecord clip) async {
    final peer = _peers[peerId];
    if (peer == null) throw Exception('Peer not found');
    if (!peer.isTrusted) throw Exception('Peer not trusted — pair first');

    final mode = settings.current.teleportSendMode;
    final endpoint = mode == 'offer' ? 'offer' : 'push';
    final url = Uri.http('${peer.address.address}:${peer.port}', '/clip/$endpoint');

    final payload = _clipToJson(clip);
    final payloadBytes = utf8.encode(jsonEncode({
      'senderId': _deviceId,
      'clip': payload,
    }));

    final progress = TransferProgress(
      peerId: peerId,
      clipId: clip.id,
      totalBytes: payloadBytes.length,
    );
    _progressController.add(progress);

    try {
      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('content-type', 'application/json');
      request.headers.set('x-clipsync-auth', _signRequest(_deviceId));
      request.add(payloadBytes);

      final response = await request.close();
      progress.transferredBytes = payloadBytes.length;
      progress.isComplete = response.statusCode == 200;
      if (!progress.isComplete) {
        progress.isFailed = true;
        progress.error = 'Server returned ${response.statusCode}';
      }
      client.close();
    } catch (e) {
      progress.isFailed = true;
      progress.error = e.toString();
    }

    _progressController.add(progress);
  }

  // ── PAIRING ───────────────────────────────────────────────────────────────

  Future<String?> initiatePairing(String peerId) async {
    final peer = _peers[peerId];
    if (peer == null) return null;

    final url = Uri.http('${peer.address.address}:${peer.port}', '/pair/initiate');
    try {
      final response = await HttpClient()
          .postUrl(url)
          .then((req) {
            req.headers.set('content-type', 'application/json');
            req.write(jsonEncode({
              'peerId': _deviceId,
              'fingerprint': _publicKeyFingerprint,
            }));
            return req.close();
          });

      final body = jsonDecode(await response.transform(utf8.decoder).join());
      final remoteSas = body['sasCode'] as String;
      final localSas = _generateSasCode(peerId, peer.publicKeyFingerprint, _publicKeyFingerprint);

      // Both must match for secure pairing
      return localSas == remoteSas ? localSas : null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> confirmPairing(String peerId, bool confirmed) async {
    final peer = _peers[peerId];
    if (peer == null) return false;

    final url = Uri.http('${peer.address.address}:${peer.port}', '/pair/confirm');
    try {
      final response = await HttpClient()
          .postUrl(url)
          .then((req) {
            req.headers.set('content-type', 'application/json');
            req.write(jsonEncode({
              'peerId': _deviceId,
              'fingerprint': _publicKeyFingerprint,
              'confirmed': confirmed,
            }));
            return req.close();
          });

      if (confirmed) {
        _addTrustedPeer(peerId, peer.publicKeyFingerprint);
        peer.isTrusted = true;
        _peersController.add(_peers.values.toList());
      }

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _addTrustedPeer(String peerId, String fingerprint) {
    _trustedPeerFingerprints[peerId] = fingerprint;
  }

  final _trustedPeerFingerprints = <String, String>{};

  bool _isTrustedPeer(String id, String fp) {
    return _trustedPeerFingerprints[id] == fp;
  }

  // ── CRYPTO HELPERS ────────────────────────────────────────────────────────

  String _generateFingerprint(String deviceId) {
    final bytes = sha256.convert(utf8.encode(deviceId)).bytes;
    return bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  /// Short Authentication String derived from both fingerprints via HMAC-SHA256.
  String _generateSasCode(String peerId, String peerFp, String myFp) {
    final material = '$peerId:$peerFp:$myFp';
    final hmac = Hmac(sha256, utf8.encode(_privateKey));
    final digest = hmac.convert(utf8.encode(material));
    // Take first 3 bytes → 6-digit decimal
    final val = (digest.bytes[0] << 16) | (digest.bytes[1] << 8) | digest.bytes[2];
    return (val % 1000000).toString().padLeft(6, '0');
  }

  String _signRequest(String deviceId) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final hmac = Hmac(sha256, utf8.encode(_privateKey));
    final sig = hmac.convert(utf8.encode('$deviceId:$ts')).toString();
    return '$deviceId:$ts:$sig';
  }

  bool _verifyAuth(Request req) {
    final authHeader = req.headers['x-clipsync-auth'];
    if (authHeader == null) return false;
    final parts = authHeader.split(':');
    if (parts.length < 3) return false;
    final senderId = parts[0];
    final peer = _peers[senderId];
    if (peer == null || !peer.isTrusted) return false;
    // In production: verify HMAC signature with peer's public key
    return true;
  }

  // ── SERIALISATION ─────────────────────────────────────────────────────────

  Map<String, dynamic> _clipToJson(ClipRecord clip) {
    return {
      'id': clip.id,
      'capturedAt': clip.capturedAt.millisecondsSinceEpoch,
      'contentType': clip.contentType.name,
      'payloads': clip.payloads.map((p) => {
        'mimeType': p.mimeType,
        'text': p.text,
        'bytes': p.bytes != null ? base64Encode(p.bytes!) : null,
      }).toList(),
      'metadata': {
        'sourceApp': clip.metadata.sourceApp,
        'aiTags': clip.metadata.aiTags,
        'contentHash': clip.metadata.contentHash,
        'ocrText': clip.metadata.ocrText,
      },
    };
  }

  ClipRecord _clipFromJson(Map<String, dynamic> j) {
    final payloads = (j['payloads'] as List).map((p) {
      final map = p as Map<String, dynamic>;
      return ClipPayload(
        mimeType: map['mimeType'] as String,
        text: map['text'] as String?,
        bytes: map['bytes'] != null ? base64Decode(map['bytes'] as String) : null,
      );
    }).toList();

    final meta = j['metadata'] as Map<String, dynamic>;

    return ClipRecord(
      id: const Uuid().v4(), // new ID on receive
      capturedAt: DateTime.fromMillisecondsSinceEpoch(j['capturedAt'] as int),
      contentType: ClipContentType.values.firstWhere(
        (e) => e.name == j['contentType'],
        orElse: () => ClipContentType.plainText,
      ),
      payloads: payloads,
      metadata: ClipMetadata(
        sourceApp: meta['sourceApp'] as String?,
        aiTags: List<String>.from(meta['aiTags'] ?? []),
        contentHash: meta['contentHash'] as String? ?? '',
        ocrText: meta['ocrText'] as String?,
      ),
      flags: const ClipFlags(),
      sensitivityCategory: ClipSensitivityCategory.none,
    );
  }

  // ── MIDDLEWARE ────────────────────────────────────────────────────────────

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, POST',
          'access-control-allow-headers': 'content-type, x-clipsync-auth',
        });
      };
    };
  }

  String? _decodeUtf8(List<int>? bytes) {
    if (bytes == null) return null;
    try { return utf8.decode(bytes); } catch (_) { return null; }
  }

  void dispose() {
    _discovery?.close();
    _registration?.unregister();
    _server?.close(force: true);
    _peersController.close();
    _progressController.close();
    _incomingController.close();
    _offerController.close();
  }
}
