import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../app/constants.dart';
import '../data/location_store.dart';
import '../models/mosque_location.dart';
import 'settings_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/geofence_service.dart';
import '../services/ringer_service.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final store = LocationStore();
  final geo = GeoFenceService();
  final ringer = RingerService();
  bool _dndActive = false;
  StreamSubscription<Position>? _moveSub;
  String _lastZonesSignature = '';

  bool _bgEnabled = false;
  String _nearestText = 'Looking for nearby mosques...';
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_rotationController);
    
    _init();
    _autoSetupCatalogIfFirstRun();
    _refreshDndStatus();
  }

  @override
  void dispose() {
    _stopMovementWatcher();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  (bool, String?) _insideAny(
    double lat,
    double lon,
    List<MosqueLocation> zones,
  ) {
    double best = double.infinity;
    String? label;
    bool inside = false;
    for (final m in zones) {
      final d = Geolocator.distanceBetween(lat, lon, m.lat, m.lon);
      if (d < best) {
        best = d;
        label = m.label;
      }
      if (d <= m.radius) inside = true;
    }
    return (inside, label);
  }

  Future<void> _autoSetupCatalogIfFirstRun() async {
    if (await store.getCatalogOnboarded()) return;

    String code =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toUpperCase() ??
        'AE';
    String? url = kCsvByCountry[code] ?? kCsvByCountry['AE'];

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.requestPermission();
      }
      await store.importCatalogFromCsvUrl(url!);
      await store.setCatalogEnabled(true);
      await store.setCatalogOnboarded(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🕌 Loaded mosque catalog for $code!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load catalog: $e'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startMovementWatcher() async {
    await _stopMovementWatcher();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1500,
    );
    _moveSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((pos) => _refreshZonesFor(pos));
  }

  Future<void> _stopMovementWatcher() async {
    await _moveSub?.cancel();
    _moveSub = null;
  }

  Future<void> _refreshZonesFor(Position pos) async {
    final custom = (await store.load()).where((e) => e.enabled).toList();
    final fromCatalog = await store.pickCatalogFor(
      userLat: pos.latitude,
      userLon: pos.longitude,
    );

    bool same(MosqueLocation a, MosqueLocation b) =>
        a.label.toLowerCase() == b.label.toLowerCase() &&
        (a.lat - b.lat).abs() < 1e-5 &&
        (a.lon - b.lon).abs() < 1e-5;

    final List<MosqueLocation> zones = [...custom];
    for (final m in fromCatalog) {
      if (!zones.any((c) => same(c, m))) zones.add(m);
    }

    final sig = zones
        .map(
          (m) =>
              '${m.label}|${m.lat.toStringAsFixed(5)},${m.lon.toStringAsFixed(5)}|${m.radius.round()}',
        )
        .join(';');
    if (sig == _lastZonesSignature) return;
    _lastZonesSignature = sig;

    final (insideNow, nearestLabel) = _insideAny(
      pos.latitude,
      pos.longitude,
      zones,
    );
    await geo.restartWithLocations(
      zones,
      contentTitle: insideNow ? 'Silent Mode On' : 'Normal Mode Restored',
      contentText: insideNow
          ? 'Your phone is silenced for the mosque'
          : 'You are outside mosque zones. Calls and alerts are back on.',
    );
    final vibrate = await store.getEnterModeVibrate();
    await ringer.set(
      insideNow
          ? (vibrate ? RingerModeStatus.vibrate : RingerModeStatus.silent)
          : RingerModeStatus.normal,
    );
  }

  Future<void> _refreshDndStatus() async {
    // Optional: we could detect DND via platform if needed. For now, no-op.
  }

  Future<void> _init() async {
    final enabled = await store.getBgEnabled();
    setState(() => _bgEnabled = enabled);
    await _updateNearest();
    if (_bgEnabled) {
      await _applyBackgroundState(true, showSnack: false);
    }
  }

  Future<void> _updateNearest() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() => _nearestText = 'Location services are turned off');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _nearestText = 'Location permission denied');
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final custom = await store.load();

    List<MosqueLocation> catalog = [];
    if (await store.getCatalogEnabled()) {
      catalog = await store.pickCatalogFor(
        userLat: pos.latitude,
        userLon: pos.longitude,
      );
    }

    if (custom.isEmpty && catalog.isEmpty) {
      if (!mounted) return;
      setState(() => _nearestText = 'No mosques found nearby');
      return;
    }

    MosqueLocation? bestLoc;
    double bestDist = double.infinity;
    String source = '';

    void consider(MosqueLocation m, String s) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        m.lat,
        m.lon,
      );
      if (d < bestDist) {
        bestDist = d;
        bestLoc = m;
        source = s;
      }
    }

    for (final m in custom) consider(m, 'Your location');
    for (final m in catalog) consider(m, 'Catalog');

    if (!mounted) return;
    if (bestLoc == null) {
      setState(() => _nearestText = 'No mosques found nearby');
      return;
    }

    final dist = bestDist < 1000
        ? '${bestDist.toStringAsFixed(0)} meters away'
        : '${(bestDist / 1000).toStringAsFixed(2)} km away';
    setState(() => _nearestText = '${bestLoc!.label} — $dist');
  }

  Future<void> _applyBackgroundState(
    bool enable, {
    bool showSnack = true,
  }) async {
    await _refreshDndStatus();
    if (_dndActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ DND is ON — Android may block ringer changes. Turn DND OFF for best experience.',
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    await store.setBgEnabled(enable);
    if (!enable) {
      await geo.stop();
      await _stopMovementWatcher();

      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✋ Auto-silence paused'),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Build candidate zones from CUSTOM enabled + nearby CATALOG
    final all = await store.load();
    final enabledLocs = all.where((e) => e.enabled).toList();

    if (await store.getCatalogEnabled()) {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied)
          perm = await Geolocator.requestPermission();
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          final fromCatalog = await store.pickCatalogFor(
            userLat: pos.latitude,
            userLon: pos.longitude,
          );
          bool same(MosqueLocation a, MosqueLocation b) =>
              a.label.toLowerCase() == b.label.toLowerCase() &&
              (a.lat - b.lat).abs() < 1e-5 &&
              (a.lon - b.lon).abs() < 1e-5;
          for (final m in fromCatalog) {
            if (!enabledLocs.any((c) => same(c, m))) enabledLocs.add(m);
          }
        }
      }
    }

    if (enabledLocs.isEmpty) {
      setState(() => _bgEnabled = false);
      await store.setBgEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '🕌 No mosques available. Add locations or enable catalog in Settings.',
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final locAlways = await Permission.locationAlways.request();
    if (!locAlways.isGranted) {
      setState(() => _bgEnabled = false);
      await store.setBgEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '📍 Need "Allow all the time" location permission for background detection.',
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final (insideNow, nearestLabel) = _insideAny(
      pos.latitude,
      pos.longitude,
      enabledLocs,
    );
    final ok = await geo.startWithLocations(
      enabledLocs,
      contentTitle: insideNow ? 'Silent Mode On' : 'Normal Mode Restored',
      contentText: insideNow
          ? 'Your phone is silenced for the mosque'
          : 'You are outside mosque zones. Calls and alerts are back on.',
    );
    await _startMovementWatcher();
    final vibrate = await store.getEnterModeVibrate();
    await ringer.set(
      insideNow
          ? (vibrate ? RingerModeStatus.vibrate : RingerModeStatus.silent)
          : RingerModeStatus.normal,
    );
    await _refreshZonesFor(pos);

    if (!ok) {
      setState(() => _bgEnabled = false);
      await store.setBgEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Failed to start background monitoring'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied)
          perm = await Geolocator.requestPermission();
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          bool inside = false;
          for (final m in enabledLocs) {
            final d = Geolocator.distanceBetween(
              p.latitude,
              p.longitude,
              m.lat,
              m.lon,
            );
            if (d <= m.radius) {
              inside = true;
              break;
            }
          }
          await ringer.set(
            inside ? RingerModeStatus.silent : RingerModeStatus.normal,
          );
        }
      }
    } catch (_) {}

    final notifStatus = await Permission.notification.request();
    final notifOk = notifStatus.isGranted || notifStatus.isLimited;
    if (!notifOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔔 Allow notifications to see status updates'),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Auto-silence is now active!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    final enabled = await store.getBgEnabled();
    setState(() => _bgEnabled = enabled);
    await _updateNearest();
    if (_bgEnabled) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await _refreshZonesFor(pos);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Enhanced gradient background with multiple colors
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Dark slate
                  Color(0xFF1E293B), // Darker slate
                  Color(0xFF0F4C4C), // Dark teal
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          
          // Animated background elements
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF07828A).withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Positioned(
            bottom: -80,
            left: -80,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.purple.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enhanced header with colorful elements
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF07828A).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/brand/app_logo.svg',
                          height: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MosqueSilence',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Respectful silence, automatically',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF07828A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.settings, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Enhanced main status card with animations
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Animated status icon
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _bgEnabled ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: _bgEnabled
                                        ? [Colors.green.shade400, Colors.teal.shade400]
                                        : [Colors.grey.shade600, Colors.grey.shade400],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _bgEnabled
                                          ? Colors.green.withOpacity(0.4)
                                          : Colors.grey.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _bgEnabled ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          _bgEnabled ? 'Auto-silence is ON' : 'Auto-silence is OFF',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          _bgEnabled
                              ? 'Your phone will automatically go silent at mosques and return to normal when you leave.'
                              : 'Turn on auto-silence to automatically silence your phone at mosques.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Enhanced toggle button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _bgEnabled
                                    ? [Colors.orange.shade500, Colors.red.shade500]
                                    : [const Color(0xFF07828A), Colors.teal.shade400],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _bgEnabled
                                      ? Colors.orange.withOpacity(0.4)
                                      : const Color(0xFF07828A).withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                setState(() => _bgEnabled = !_bgEnabled);
                                _applyBackgroundState(_bgEnabled);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: Icon(
                                _bgEnabled ? Icons.pause_rounded : Icons.play_arrow_rounded,color: Colors.white,
                                size: 24,
                              ),
                              label: Text(
                                _bgEnabled ? 'Pause Auto-silence' : 'Start Auto-silence',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Enhanced nearest mosque card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.purple.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nearest Mosque',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nearestText,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _updateNearest();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text('Refresh Location'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Enhanced how it works section
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.teal.withOpacity(0.1),
                          Colors.cyan.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.teal.withOpacity(0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.teal.shade400, Colors.cyan.shade400],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.lightbulb_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'How It Works',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        _buildHowItWorksItem(
                          '🚀',
                          'Turn it on and we\'ll run quietly in the background',
                          Colors.green,
                        ),
                        _buildHowItWorksItem(
                          '📍',
                          'Allow "Location — All the time" when asked (needed for background detection)',
                          Colors.blue,
                        ),
                        _buildHowItWorksItem(
                          '🔇',
                          'We automatically silence your phone when you enter mosque areas',
                          Colors.orange,
                        ),
                        _buildHowItWorksItem(
                          '🔊',
                          'Sound returns to normal when you leave the mosque',
                          Colors.purple,
                        ),
                        _buildHowItWorksItem(
                          '⚙️',
                          'Customize locations and settings in the Settings page',
                          Colors.teal,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.update_rounded,
                                color: Color(0xFF07828A),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Updates automatically when you move ~1.5km',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Enhanced brand footer
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/brand/app_logo.png',
                              height: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MosqueSilence',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksItem(String emoji, String text, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }}