import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants.dart';
import '../models/mosque_location.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:geolocator/geolocator.dart';

class LocationStore {
  Future<List<MosqueLocation>> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(kStoreLocations);
    if (s == null) return [];
    return decodeLocations(s);
  }

  Future<void> save(List<MosqueLocation> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kStoreLocations, encodeLocations(items));
  }

  Future<bool> getPersistNotif() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(kStorePersistNotif) ?? true;
  }

  Future<void> setPersistNotif(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kStorePersistNotif, v);
  }

  Future<bool> getBgEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(kStoreBgEnabled) ?? false;
  }

  Future<void> setBgEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kStoreBgEnabled, v);
  }

  // ---- Catalog toggles/settings ----
  Future<bool> getCatalogEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(kStoreCatalogEnabled) ?? false;
  }

  Future<void> setCatalogEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kStoreCatalogEnabled, v);
  }

  Future<int> getCatalogMaxCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(kStoreCatalogMaxCount) ?? kDefaultCatalogMaxCount;
  }

  Future<void> setCatalogMaxCount(int n) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(kStoreCatalogMaxCount, n);
  }

  Future<double> getCatalogMaxKm() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(kStoreCatalogMaxKm) ?? kDefaultCatalogMaxKm;
  }

  Future<void> setCatalogMaxKm(double km) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(kStoreCatalogMaxKm, km);
  }

  // ---- Defaults / Advanced ----
  Future<double> getDefaultRadiusMeters() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getDouble(kStoreDefaultRadiusMetersKey);
    if (v == null) return kDefaultRadiusMeters;
    return v.clamp(20, 200);
  }

  Future<void> setDefaultRadiusMeters(double meters) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(kStoreDefaultRadiusMetersKey, meters.clamp(20, 200));
  }

  Future<bool> getEnterModeVibrate() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(kStoreEnterModeVibrate) ?? false;
  }

  Future<void> setEnterModeVibrate(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kStoreEnterModeVibrate, v);
  }

  Future<int> getCatalogLastFetchMs() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(kStoreCatalogLastFetchMs) ?? 0;
  }

  Future<void> setCatalogLastFetchMs(int msSinceEpoch) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(kStoreCatalogLastFetchMs, msSinceEpoch);
  }

  // ---- Catalog data ----
  Future<void> saveCatalog(List<MosqueLocation> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kStoreCatalog, encodeLocations(items));
  }

  Future<List<MosqueLocation>> loadCatalog() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(kStoreCatalog);
    if (s == null) return [];
    return decodeLocations(s);
  }

  Future<int> importCatalogFromCsvUrl(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    // Strip BOM if present
    var text = resp.body;
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(text);

    if (rows.isEmpty) {
      await saveCatalog([]);
      return 0;
    }

    // Find first non-empty row as header
    int headerRow = 0;
    while (headerRow < rows.length &&
        (rows[headerRow].isEmpty ||
            (rows[headerRow][0].toString().trim().isEmpty))) {
      headerRow++;
    }
    if (headerRow >= rows.length) {
      await saveCatalog([]);
      return 0;
    }

    final header = rows[headerRow]
        .map((e) => e.toString().trim().toLowerCase())
        .toList();

    int idxOf(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final iLabel = idxOf(['label', 'name', 'mosque', 'title']);
    final iLat = idxOf(['lat', 'latitude']);
    final iLon = idxOf(['lon', 'lng', 'longitude']);
    final iRad = idxOf(['radius', 'radius_m', 'rad_m']);

    if (iLat < 0 || iLon < 0) {
      throw Exception('CSV missing latitude/longitude columns');
    }

    // Helper: safe cell
    String cell(List row, int i) =>
        (i >= 0 && i < row.length) ? row[i].toString().trim() : '';

    // Helper: forgiving double parser (keeps digits, sign, dot)
    double? parseNum(String s) {
      final cleaned = s.replaceAll(RegExp(r'[^0-9\.\-+]'), '');
      return double.tryParse(cleaned);
    }

    final List<MosqueLocation> catalog = [];
    for (int r = headerRow + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      final label = cell(row, iLabel).isEmpty ? 'Mosque' : cell(row, iLabel);
      final lat = parseNum(cell(row, iLat));
      final lon = parseNum(cell(row, iLon));
      final rad = parseNum(cell(row, iRad)) ?? kDefaultRadiusMeters;

      if (lat == null || lon == null) continue;

      catalog.add(
        MosqueLocation(
          label: label,
          lat: lat,
          lon: lon,
          radius: rad,
          enabled: true, // eligible when catalog is enabled
        ),
      );
    }

    await saveCatalog(catalog);
    await setCatalogLastFetchMs(DateTime.now().millisecondsSinceEpoch);
    return catalog.length;
  }

  /// Pick nearby catalog locations (nearest N within R km) without exposing all 3k items
  Future<List<MosqueLocation>> pickCatalogFor({
    required double userLat,
    required double userLon,
  }) async {
    final enabled = await getCatalogEnabled();
    if (!enabled) return [];

    // Auto refetch if older than 7 days
    final last = await getCatalogLastFetchMs();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last == 0 || now - last > 7 * 24 * 60 * 60 * 1000) {
      try {
        // Use default country URL for now
        await importCatalogFromCsvUrl(kDefaultCsvUrl);
      } catch (_) {}
    }

    final maxCount = await getCatalogMaxCount();
    final maxKm = await getCatalogMaxKm();
    final maxMeters = maxKm * 1000;

    final all = await loadCatalog();
    if (all.isEmpty) return [];

    // compute distance to user, filter by radius
    final withDist = <(MosqueLocation, double)>[];
    for (final m in all) {
      final d = Geolocator.distanceBetween(userLat, userLon, m.lat, m.lon);
      if (d <= maxMeters) withDist.add((m, d));
    }
    // sort nearest, take N
    withDist.sort((a, b) => a.$2.compareTo(b.$2));
    final picked = withDist.take(maxCount).map((e) => e.$1).toList();
    return picked;
  }

  Future<bool> getCatalogOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(kStoreCatalogOnboarded) ?? false;
  }

  Future<void> setCatalogOnboarded(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kStoreCatalogOnboarded, v);
  }
}
