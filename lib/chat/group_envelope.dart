import 'dart:convert';

/// Canonical-bytes serializer for signature inputs.
/// - Top-level keys sorted alphabetically (recursively).
/// - No whitespace.
/// - Lists preserved in order.
/// - Optionally omit a single top-level field (for stripping `sig` before sign/verify).
List<int> canonicalJsonBytes(Map<String, dynamic> obj, {String? omit}) {
  final entries = obj.entries
      .where((e) => omit == null || e.key != omit)
      .map((e) => MapEntry(e.key, _canon(e.value)))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final ordered = <String, dynamic>{
    for (final e in entries) e.key: e.value
  };
  return utf8.encode(jsonEncode(ordered));
}

dynamic _canon(dynamic v) {
  if (v is Map<String, dynamic>) {
    final entries = v.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: _canon(e.value)};
  }
  if (v is List) return v.map(_canon).toList();
  return v;
}
