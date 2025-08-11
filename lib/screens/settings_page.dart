import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../app/constants.dart';
import '../data/location_store.dart';
import '../models/mosque_location.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  final store = LocationStore();
  List<MosqueLocation> _items = [];
  bool _catalogEnabled = false;
  int _catalogMaxCount = kDefaultCatalogMaxCount;
  double _catalogMaxKm = kDefaultCatalogMaxKm;
  double _defaultRadiusM = kDefaultRadiusMeters;
  bool _enterModeVibrate = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _load();
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await store.load();
    await store.getPersistNotif();
    _catalogEnabled = await store.getCatalogEnabled();
    _catalogMaxCount = await store.getCatalogMaxCount();
    _catalogMaxKm = await store.getCatalogMaxKm();
    _defaultRadiusM = await store.getDefaultRadiusMeters();
    _enterModeVibrate = await store.getEnterModeVibrate();

    setState(() {
      _items = items;
    });
  }

  Future<void> _saveAll() async {
    await store.save(_items);
  }

  Future<void> _addCurrent() async {
    final ok = await _ensurePermission();
    if (!ok) return;
    final p = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final labelController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return _buildThemedDialog(
          title: '🕌 Label This Mosque',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Give this location a friendly name so you can easily recognize it later!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g., Jumeirah Mosque, Al Noor Mosque',
                  hintStyle: TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.edit_rounded, color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: const Text('Save Location'),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final item = MosqueLocation(
      label: labelController.text.trim().isEmpty
          ? 'Mosque'
          : labelController.text.trim(),
      lat: p.latitude,
      lon: p.longitude,
      radius: kDefaultRadiusMeters,
      enabled: true,
    );
    setState(() => _items = [..._items, item]);
    await _saveAll();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Added "${item.label}" to your locations!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<void> _addByCoords() async {
    final label = TextEditingController();
    final lat = TextEditingController();
    final lon = TextEditingController();
    final radius = TextEditingController(
      text: kDefaultRadiusMeters.toStringAsFixed(0),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _buildThemedDialog(
        title: '📍 Add Mosque by Coordinates',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the precise coordinates and details for this mosque location.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildDialogTextField(label, 'Mosque Name', Icons.mosque_rounded),
            const SizedBox(height: 12),
            _buildDialogTextField(lat, 'Latitude', Icons.location_on_rounded, isNumber: true),
            const SizedBox(height: 12),
            _buildDialogTextField(lon, 'Longitude', Icons.location_on_rounded, isNumber: true),
            const SizedBox(height: 12),
            _buildDialogTextField(radius, 'Detection Radius (meters)', Icons.radio_button_unchecked_rounded, isNumber: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('Add Mosque'),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final parsedLat = double.tryParse(lat.text.trim());
    final parsedLon = double.tryParse(lon.text.trim());
    final parsedR = double.tryParse(radius.text.trim());

    if (parsedLat == null || parsedLon == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Please enter valid numbers for latitude and longitude'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final item = MosqueLocation(
      label: (label.text.trim().isEmpty) ? 'Mosque' : label.text.trim(),
      lat: parsedLat,
      lon: parsedLon,
      radius: parsedR ?? kDefaultRadiusMeters,
      enabled: true,
    );
    setState(() => _items = [..._items, item]);
    await _saveAll();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Added "${item.label}" by coordinates!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@mosquesilence.app',
      queryParameters: {
        'subject': 'MosqueSilence Support',
        'body': 'Hi,\n\n',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(const ClipboardData(text: 'support@mosquesilence.app'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📧 Email address copied to clipboard!'),
          backgroundColor: Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCustomList() {
    return FutureBuilder<List<MosqueLocation>>(
      future: store.load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF07828A)),
              ),
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  size: 48,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No custom locations yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the buttons below to add your favorite mosque locations for personalized auto-silence.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final m = items[i];
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: m.enabled
                            ? [Colors.green.shade400, Colors.teal.shade400]
                            : [Colors.grey.shade600, Colors.grey.shade500],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.mosque_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${m.lat.toStringAsFixed(5)}, ${m.lon.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        Text(
                          '📏 ${m.radius.round()} meters detection radius',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: m.enabled,
                    activeColor: Colors.green.shade400,
                    inactiveThumbColor: Colors.grey.shade400,
                    onChanged: (v) async {
                      HapticFeedback.lightImpact();
                      final list = await store.load();
                      final idx = list.indexWhere(
                        (e) =>
                            e.label == m.label &&
                            e.lat == m.lat &&
                            e.lon == m.lon,
                      );
                      if (idx >= 0) {
                        list[idx] = MosqueLocation(
                          label: m.label,
                          lat: m.lat,
                          lon: m.lon,
                          radius: m.radius,
                          enabled: v,
                        );
                        await store.save(list);
                        setState(() {});
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              v ? '✅ Enabled ${m.label}' : '⏸️ Disabled ${m.label}',
                            ),
                            backgroundColor: v ? Colors.green.shade600 : Colors.orange.shade600,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete location',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => _buildThemedDialog(
                          title: '🗑️ Delete Location',
                          content: Text(
                            'Are you sure you want to remove "${m.label}" from your saved locations?',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red.shade500, Colors.red.shade600],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true) {
                        final list = await store.load();
                        list.removeWhere(
                          (e) =>
                              e.label == m.label &&
                              e.lat == m.lat &&
                              e.lon == m.lon,
                        );
                        await store.save(list);
                        setState(() {});
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🗑️ Deleted "${m.label}"'),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemedDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        dialogBackgroundColor: const Color(0xFF1E293B),
      ),
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: content,
        actions: actions,
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Enhanced gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0F4C4C),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          
          // Animated background decorations
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
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
          ),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Enhanced header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset('assets/brand/app_logo.png', height: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settings',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Customize your experience',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF07828A),
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
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Enhanced catalog section
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.withOpacity(0.15),
                              Colors.cyan.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade400, Colors.cyan.shade400],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.public_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Nearby Mosque Catalog',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Switch(
                                    value: _catalogEnabled,
                                    activeColor: Colors.green.shade400,
                                    onChanged: (v) async {
                                      HapticFeedback.lightImpact();
                                      setState(() => _catalogEnabled = v);
                                      await store.setCatalogEnabled(v);
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            v ? '✅ Catalog enabled!' : '⏸️ Catalog disabled',
                                          ),
                                          backgroundColor: v ? Colors.green.shade600 : Colors.orange.shade600,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auto-include nearby mosques',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Automatically finds mosques near you from our curated database',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  try {
                                    final n = await store.importCatalogFromCsvUrl(kDefaultCsvUrl);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('🔄 Catalog updated: $n mosques loaded!'),
                                        backgroundColor: Colors.green.shade600,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('❌ Failed to update catalog: $e'),
                                        backgroundColor: Colors.red.shade600,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.cloud_download_rounded, color: Colors.white),
                                label: const Text('Update Mosque Catalog',style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Advanced settings expansion
                            Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: const Color.fromARGB(0, 255, 255, 255),
                                expansionTileTheme: ExpansionTileThemeData(
                                  iconColor: Colors.white70,
                                  collapsedIconColor: Colors.white70,
                                ),
                              ),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  '🔧 Advanced Catalog Settings',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Fine-tune how many nearby mosques we track',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.format_list_numbered_rounded, color: Colors.white70, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Maximum mosques to track: $_catalogMaxCount',
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                min: 10,
                                                max: 100,
                                                divisions: 18,
                                                value: _catalogMaxCount.toDouble(),
                                                label: '$_catalogMaxCount mosques',
                                                activeColor: const Color(0xFF07828A),
                                                inactiveColor: Colors.white24,
                                                onChanged: (v) => setState(() => _catalogMaxCount = v.round()),
                                                onChangeEnd: (v) => store.setCatalogMaxCount(v.round()),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.radar_rounded, color: Colors.white70, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Search radius: ${_catalogMaxKm.toStringAsFixed(0)} km',
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                min: 5,
                                                max: 50,
                                                divisions: 45,
                                                value: _catalogMaxKm,
                                                label: '${_catalogMaxKm.toStringAsFixed(0)} km',
                                                activeColor: const Color(0xFF07828A),
                                                inactiveColor: Colors.white24,
                                                onChanged: (v) => setState(() => _catalogMaxKm = v),
                                                onChangeEnd: (v) => store.setCatalogMaxKm(v),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Enhanced detection settings
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple.withOpacity(0.15),
                              Colors.pink.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.purple.shade400, Colors.pink.shade400],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Detection Settings',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Text(
                              'Fine-tune how close you need to be to a mosque before your phone goes silent. Smaller radius = more precise, larger radius = earlier detection.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.adjust_rounded, color: Colors.white70, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Default detection radius: ${_defaultRadiusM.round()} meters',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Slider(
                                    min: 20,
                                    max: 200,
                                    divisions: 180,
                                    value: _defaultRadiusM,
                                    label: '${_defaultRadiusM.round()}m',
                                    activeColor: Colors.purple.shade400,
                                    inactiveColor: Colors.white24,
                                    onChanged: (v) => setState(() => _defaultRadiusM = v),
                                    onChangeEnd: (v) => store.setDefaultRadiusMeters(v),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Switch(
                                    value: _enterModeVibrate,
                                    activeColor: Colors.orange.shade400,
                                    onChanged: (v) async {
                                      HapticFeedback.lightImpact();
                                      setState(() => _enterModeVibrate = v);
                                      await store.setEnterModeVibrate(v);
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            v ? '📳 Vibrate mode enabled!' : '🔇 Silent mode enabled',
                                          ),
                                          backgroundColor: v ? Colors.orange.shade600 : Colors.blue.shade600,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Vibrate instead of Silent',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Your phone will vibrate (not go silent) when inside mosques',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Enhanced custom locations section
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.teal.withOpacity(0.15),
                              Colors.green.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.teal.shade400, Colors.green.shade400],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Your Personal Locations',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            _buildCustomList(),
                            
                            const SizedBox(height: 16),
                            
                            
                            // Add location buttons
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF07828A), Color(0xFF0EA5E9)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        _addCurrent();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.my_location_rounded, color: Colors.white),
                                      label: const Text('Current Location',style: TextStyle(color: Color.fromARGB(255, 239, 240, 241))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.teal.shade500, Colors.green.shade500],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        _addByCoords();
                                        
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
                                      label: const Text('By Coordinates',style: TextStyle(color: Color.fromARGB(255, 239, 240, 241))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                                                        // Email suggestion
                            
                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Column(
                                children: [
                                Icon(
                                  Icons.mail_rounded,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Found a mosque we missed?',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Help us improve by sharing mosque locations to add to our catalog!',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final uri = Uri(
                                        scheme: 'mailto',
                                        path: 'akhmad6093@gmail.com',
                                        queryParameters: {
                                          'subject': '[MosqueSilence] New mosque location',
                                          'body': 'Please add this mosque to the catalog.\n\n'
                                                  '🕌 Mosque Name: <enter name>\n'
                                                  '📍 Latitude: <enter lat>\n'
                                                  '📍 Longitude: <enter lon>\n'
                                                  '📏 Suggested radius (meters): <enter 20-200>\n\n'
                                                  'Thanks for helping improve MosqueSilence!',
                                        },
                                      );

                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        await Clipboard.setData(const ClipboardData(text: 'akhmad6093@gmail.com'));
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('📧 Email address copied to clipboard!'),
                                            backgroundColor: Colors.blue.shade600,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    icon: Icon(Icons.mail_outline_rounded, color: Colors.blue.shade400),
                                    label: Text(
                                      'Email us a location',
                                      style: TextStyle(color: Colors.blue.shade400),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}