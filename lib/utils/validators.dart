// lib/utils/validators.dart

int? parsePositiveInt(String? value) {
  if (value == null) return null;
  final v = int.tryParse(value.trim());
  if (v == null || v <= 0) return null;
  return v;
}
