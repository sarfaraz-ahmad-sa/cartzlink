String normalizeErpHost(String input) {
  var value = input.trim();
  if (value.isEmpty) return '';

  try {
    final candidate = value.contains('://') ? value : 'https://$value';
    final uri = Uri.parse(candidate);
    if (uri.host.isNotEmpty) return uri.host.toLowerCase();
  } catch (_) {}

  value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  value = value.replaceFirst(RegExp(r'/.*$'), '');
  value = value.replaceFirst(RegExp(r'/+$'), '');
  return value.toLowerCase();
}

String normalizeLegacyUser(String? input) {
  var value = (input ?? '')
      .replaceAll(RegExp(r'[\u200B-\u200D\u2060\u00A0]'), '')
      .trim();
  const replacements = <String, String>{
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };
  for (final entry in replacements.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value;
}

String ensureHttps(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  return 'https://$trimmed';
}

String originOrDefault(String value, {String fallback = ''}) {
  try {
    final trimmed = value.trim();
    final uri = Uri.parse(trimmed.contains('://') ? trimmed : ensureHttps(trimmed));
    if (uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return fallback;
    }
    return Uri(
      scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString().replaceFirst(RegExp(r'/$'), '');
  } catch (_) {
    return fallback;
  }
}

bool sameOrigin(String a, String b) {
  try {
    final ua = Uri.parse(a);
    final ub = Uri.parse(b);
    return ua.scheme == ub.scheme && ua.host == ub.host && ua.port == ub.port;
  } catch (_) {
    return false;
  }
}
