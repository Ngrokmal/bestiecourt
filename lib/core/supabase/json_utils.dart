/// Defensive JSON helpers. Server payloads are untrusted input: never cast
/// blindly and never assume a field exists.

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map<dynamic, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asJsonList(Object? value) {
  if (value is List<dynamic>) {
    return value.map(asJsonMap).toList(growable: false);
  }
  return <Map<String, dynamic>>[];
}

String asString(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

String? asStringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

DateTime? asDateOrNull(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
