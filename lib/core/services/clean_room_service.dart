import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class CleanRoomResult {
  final String originalUrl;
  final String cleanedUrl;
  final List<String> removedParams;
  final bool wasRedirectResolved;
  final bool wasModified;

  const CleanRoomResult({
    required this.originalUrl,
    required this.cleanedUrl,
    required this.removedParams,
    this.wasRedirectResolved = false,
    required this.wasModified,
  });
}

/// Strips tracking parameters, metadata, and fingerprinting artifacts
/// from URLs, text, and binary payloads.
class CleanRoomService {

  // ── URL CLEANING ─────────────────────────────────────────────────────────

  Future<CleanRoomResult> processUrl(String rawUrl) async {
    final removed = <String>[];
    String current = rawUrl.trim();

    // Pass 1: structural normalization
    current = _normalizeUrl(current);

    // Pass 2: tracking parameter removal
    final paramResult = _removeTrackingParams(current);
    current = paramResult.url;
    removed.addAll(paramResult.removed);

    // Pass 3: redirect unwrapping
    bool redirectResolved = false;
    if (_isRedirectUrl(current)) {
      final resolved = await _resolveRedirect(current);
      if (resolved != null && resolved != current) {
        current = resolved;
        redirectResolved = true;
        // Re-clean the resolved URL
        final reClean = _removeTrackingParams(current);
        current = reClean.url;
        removed.addAll(reClean.removed);
      }
    }

    return CleanRoomResult(
      originalUrl: rawUrl,
      cleanedUrl: current,
      removedParams: removed,
      wasRedirectResolved: redirectResolved,
      wasModified: current != rawUrl || redirectResolved,
    );
  }

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Lowercase scheme and host
      final normalized = uri.replace(
        scheme: uri.scheme.toLowerCase(),
        host: uri.host.toLowerCase(),
      );
      return normalized.toString();
    } catch (_) {
      return url;
    }
  }

  ({String url, List<String> removed}) _removeTrackingParams(String url) {
    final removed = <String>[];
    try {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);

      for (final param in _trackingParameters) {
        if (params.containsKey(param)) {
          removed.add('$param=${params[param]}');
          params.remove(param);
        }
      }
      // Also remove params matching tracking patterns
      final keysToRemove = params.keys.where((k) =>
        _trackingPrefixes.any((prefix) => k.startsWith(prefix))
      ).toList();
      for (final key in keysToRemove) {
        removed.add('$key=${params[key]}');
        params.remove(key);
      }

      final cleaned = uri.replace(queryParameters: params.isEmpty ? null : params);
      return (url: cleaned.toString(), removed: removed);
    } catch (_) {
      return (url: url, removed: removed);
    }
  }

  bool _isRedirectUrl(String url) {
    return _redirectDomains.any((d) => url.contains(d));
  }

  Future<String?> _resolveRedirect(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );
      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) return location;
      if (response.isRedirect) return response.headers['location'];
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── TEXT CLEANING ─────────────────────────────────────────────────────────

  /// Remove zero-width and invisible Unicode characters used for fingerprinting.
  String stripZeroWidthChars(String text) {
    return text.replaceAll(RegExp(
      '[\u200B\u200C\u200D\u200E\u200F\u202A-\u202E\u2060-\u2064\uFEFF\u00AD]'
    ), '');
  }

  /// Strip HTML tracking attributes and editor fingerprints.
  String stripHtmlMetadata(String html) {
    return html
      // data-user-* attributes
      .replaceAll(RegExp(r'\s+data-user-[a-z\-]+=[""][^""]*[""]'), '')
      // MSO editor markers
      .replaceAll(RegExp(r'<!--\[if[^\]]*\]>.*?<!\[endif\]-->', dotAll: true), '')
      // Google Docs revision markers
      .replaceAll(RegExp(r'\s+data-doc-[a-z\-]+=[""][^""]*[""]'), '')
      // Zero-width spaces in attribute values
      .replaceAll(RegExp(r'[\u200B\u200C\u200D]'), '');
  }

  // ── IMAGE EXIF STRIPPING ──────────────────────────────────────────────────

  /// Strip EXIF metadata from image bytes. Returns cleaned bytes.
  Uint8List stripExif(Uint8List imageBytes, {bool gpsOnly = true}) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return imageBytes;

      if (gpsOnly) {
        decoded.exif.data.remove(0x8825); // GPSInfo tag
        decoded.exif.data.remove(0x0001); // GPSLatitudeRef
        decoded.exif.data.remove(0x0002); // GPSLatitude
        decoded.exif.data.remove(0x0003); // GPSLongitudeRef
        decoded.exif.data.remove(0x0004); // GPSLongitude
        decoded.exif.data.remove(0x001D); // GPSDateStamp
        decoded.exif.data.remove(0x0007); // GPSTimeStamp
      } else {
        // Strip all EXIF except ICC color profile
        final icc = decoded.exif.data[0x8773];
        decoded.exif.data.clear();
        if (icc != null) decoded.exif.data[0x8773] = icc;
      }

      return Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
    } catch (_) {
      return imageBytes;
    }
  }

  // ── KNOWN TRACKING PARAMETERS ─────────────────────────────────────────────

  static const _trackingParameters = {
    // UTM
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'utm_id', 'utm_source_platform', 'utm_creative_format', 'utm_marketing_tactic',
    // Meta / Facebook
    'fbclid', 'fb_action_ids', 'fb_action_types', 'fb_ref', 'fb_source',
    // Google
    'gclid', 'gclsrc', 'dclid',
    // Microsoft
    'msclkid',
    // Yandex
    'yclid',
    // Mailchimp
    'mc_eid', 'mc_cid',
    // HubSpot
    '_hsenc', '_hsmi',
    // Marketo
    'mkt_tok',
    // Klaviyo
    '_kx',
    // Vero
    'vero_id', 'vero_conv',
    // Salesforce
    'sfmc_id', 'sfmc_activityid',
    // Drip
    '__s',
    // Twitter / X
    'twclid',
    // TikTok
    'ttclid',
    // LinkedIn
    'li_fat_id',
    // Pinterest
    'epik',
    // Reddit
    'rdt_cid',
    // Generic
    'ref', 'referrer', 'source', 'campaign', 'trk', 'tracking_id',
    'affiliate_id', 'partner_id', 'click_id', 'session_id',
    // Analytics
    '_ga', '_gl', 'igshid',
  };

  static const _trackingPrefixes = [
    'utm_', 'fb_', 'ga_', '_hs', 'sf_', 'mkto_',
  ];

  static const _redirectDomains = [
    'bit.ly', 't.co', 'tinyurl.com', 'ow.ly', 'buff.ly',
    'click.mailchimp.com', 'list-manage.com', 'r.emaillink.stripe.com',
    'l.facebook.com', 'lnkd.in', 'redirect.', 'track.', 'click.',
  ];
}
