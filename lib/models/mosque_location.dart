import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class MosqueLocation {
  final String id;
  final String label;
  final double lat;
  final double lon;
  final double radius;
  final bool enabled;

  MosqueLocation({
    String? id,
    required this.label,
    required this.lat,
    required this.lon,
    this.radius = 150,
    this.enabled = true,
  }) : id = id ?? _uuid.v4();

  MosqueLocation copyWith({
    String? id,
    String? label,
    double? lat,
    double? lon,
    double? radius,
    bool? enabled,
  }) {
    return MosqueLocation(
      id: id ?? this.id,
      label: label ?? this.label,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      radius: radius ?? this.radius,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lon': lon,
        'radius': radius,
        'enabled': enabled,
      };

  static MosqueLocation fromJson(Map<String, dynamic> j) => MosqueLocation(
        id: j['id'] as String?,
        label: j['label'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        radius: (j['radius'] as num?)?.toDouble() ?? 150,
        enabled: j['enabled'] as bool? ?? true,
      );
}

String encodeLocations(List<MosqueLocation> items) =>
    jsonEncode(items.map((e) => e.toJson()).toList());

List<MosqueLocation> decodeLocations(String s) {
  final raw = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
  return raw.map(MosqueLocation.fromJson).toList();
}
