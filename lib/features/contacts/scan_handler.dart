/// Result of parsing a scanned QR string in the Add Contact flow.
class ScanResult {
  const ScanResult.valid(this.pubkeyHex)
      : isValid = true,
        error = null;

  const ScanResult.invalid(this.error)
      : isValid = false,
        pubkeyHex = null;

  final bool isValid;
  final String? pubkeyHex;
  final String? error;
}

/// Pure parsing logic for QR-scanned identity strings.
/// Phase 10.1 format: just the 64-char lowercase hex Ed25519 public key.
/// Later phases will extend to include a relay URL and display name.
class ScanHandler {
  ScanHandler._();

  static ScanResult parse(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return const ScanResult.invalid('QR is empty');
    }
    if (trimmed.length != 64) {
      return ScanResult.invalid(
        'expected 64 hex chars, got ${trimmed.length}',
      );
    }
    if (!_isHex(trimmed)) {
      return const ScanResult.invalid('QR is not valid hex');
    }
    return ScanResult.valid(trimmed);
  }

  static bool _isHex(String s) {
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      final ok =
          (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66); // 0-9 a-f
      if (!ok) return false;
    }
    return true;
  }
}
