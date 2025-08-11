const String kServiceChannelId = 'com.mosquesilence.geofence';
const int kServiceNotificationId =
    525600; // Foreground service notif (do not cancel)
const int kStatusNotificationId =
    525601; // Optional status notif (safe to cancel)

const String kPrefsPinLat = 'pin_lat';
const String kPrefsPinLon = 'pin_lon';
const String kPrefsAutoEnabled = 'auto_enabled';
const String kPrefsAutoRadius = 'auto_radius';

const double kDefaultRadiusMeters = 150;
const double kExitHysteresisMeters = 25;

const String kStoreLocations = 'locations';
const String kStorePersistNotif = 'persist_notif';
const String kStoreBgEnabled = 'bg_enabled';
const String kStoreCatalog = 'catalog_locations';
const String kStoreCatalogEnabled = 'catalog_enabled';
const String kStoreCatalogMaxCount = 'catalog_max_count';
const String kStoreCatalogMaxKm = 'catalog_max_km';
const String kStoreDefaultRadiusMetersKey = 'default_radius_m';
const String kStoreEnterModeVibrate = 'enter_mode_vibrate';
const String kStoreCatalogLastFetchMs = 'catalog_last_fetch_ms';

const int kDefaultCatalogMaxCount = 90;
const double kDefaultCatalogMaxKm = 10; // 10 km radius default

// add near your other constants
const String kStoreCatalogOnboarded = 'catalog_onboarded';

const String kDefaultCsvUrl =
    'https://raw.githubusercontent.com/Astrobubu/MasjidSilencerApp/main/uae_mosques.csv';

// map by country code (expand later; for now just UAE)
const Map<String, String> kCsvByCountry = {'AE': kDefaultCsvUrl};
