import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Authentication strategy for the Marello (Oro) REST API.
///
/// Kept behind an interface so the transport in [MarelloService] never depends
/// on *how* requests are authenticated. This install uses WSSE
/// ([WsseAuth]); swapping to OAuth2 later means dropping in a new
/// implementation of [authHeaders] — no changes to the service or UI.
abstract class MarelloAuth {
  /// Fresh auth headers for a single request. Async so a future OAuth2
  /// implementation can refresh a token here transparently.
  Future<Map<String, String>> authHeaders();
}

/// WSSE UsernameToken authentication, as expected by Oro's EscapeWSSE bundle.
///
/// Per request it sends an `X-WSSE` header whose digest is
/// `base64( sha1( rawNonce + created + apiKey ) )`, where `rawNonce` is the
/// raw (base64-decoded) bytes of the `Nonce` field. The [apiKey] is the
/// user's API key generated in the Marello admin (My User → Generate Key).
///
/// Security note: WSSE only protects the key itself — always send over HTTPS.
class WsseAuth implements MarelloAuth {
  WsseAuth({required this.username, required this.apiKey, Random? random})
      : _random = random ?? Random.secure();

  final String username;
  final String apiKey;
  final Random _random;

  @override
  Future<Map<String, String>> authHeaders() async {
    final nonceBytes =
        List<int>.generate(16, (_) => _random.nextInt(256), growable: false);
    final nonce = base64.encode(nonceBytes);
    final created = _iso8601Now();

    // Oro/EscapeWSSE: digest over the RAW nonce bytes, not the base64 string.
    final digestInput = <int>[
      ...nonceBytes,
      ...utf8.encode(created),
      ...utf8.encode(apiKey),
    ];
    final digest = base64.encode(sha1.convert(digestInput).bytes);

    return {
      'Authorization': 'WSSE profile="UsernameToken"',
      'X-WSSE': 'UsernameToken '
          'Username="$username", '
          'PasswordDigest="$digest", '
          'Nonce="$nonce", '
          'Created="$created"',
    };
  }

  /// ISO-8601 with a `+00:00` offset, matching PHP's `date('c')` in UTC.
  /// The exact string is hashed into the digest, so client and server must
  /// agree on it byte-for-byte — hence no trailing `Z` shorthand.
  static String _iso8601Now() {
    final n = DateTime.now().toUtc();
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(n.year, 4)}-${p(n.month)}-${p(n.day)}'
        'T${p(n.hour)}:${p(n.minute)}:${p(n.second)}+00:00';
  }
}
