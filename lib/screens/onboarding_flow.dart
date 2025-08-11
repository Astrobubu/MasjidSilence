// File: lib/screens/onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingFlow({super.key, required this.onComplete});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequesting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      // Updated to 4 total pages (0-3)
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);

    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location services first'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Now request "Always" permission for background
        final alwaysStatus = await Permission.locationAlways.request();

        if (alwaysStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission granted!'),
                backgroundColor: Colors.green.shade700,
              ),
            );
          }
          _nextPage();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Background location is needed for automatic detection',
                ),
                backgroundColor: Colors.orange.shade700,
                action: SnackBarAction(
                  label: 'Try Again',
                  onPressed: _requestLocationPermission,
                ),
              ),
            );
          }
        }
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermanentlyDeniedDialog('location');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);

    try {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification permission granted!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
        _nextPage();
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermanentlyDeniedDialog('notification');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Notifications help you know when the app is working',
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        // Allow proceeding even without notifications
        _nextPage();
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _requestDndPermission() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);

    try {
      final status = await Permission.accessNotificationPolicy.request();

      if (status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('DND permission granted successfully!'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _nextPage();
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermanentlyDeniedDialog('DND');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'DND permission is required for the app to work. Please try again.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _requestDndPermission,
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  void _showPermanentlyDeniedDialog(String permissionType) {
    String title, content;

    switch (permissionType) {
      case 'location':
        title = 'Location Blocked';
        content =
            'Location access has been permanently blocked. Please go to Settings and enable location permissions manually.';
        break;
      case 'notification':
        title = 'Notifications Blocked';
        content =
            'Notifications have been permanently blocked. Please go to Settings and enable notifications manually.';
        break;
      case 'DND':
        title = 'DND Access Blocked';
        content =
            'Do Not Disturb access has been permanently blocked. Please go to Settings and enable DND access for this app to work properly.';
        break;
      default:
        title = 'Permission Blocked';
        content =
            'This permission has been permanently blocked. Please go to Settings and enable it manually.';
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Make it required for DND
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Colors.white.withOpacity(0.08),
          textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        child: AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (permissionType !=
                'DND') // Allow cancel for optional permissions
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator (updated for 4 pages)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  for (int i = 0; i < 4; i++) // Updated to 4 pages
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? const Color(0xFF07828A)
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildLocationPage(),
                  _buildNotificationPage(),
                  _buildDndPage(), // New DND page
                  _buildCompletePage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildPrimaryButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          Text(
            '📍 Location Access',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'MosqueSilence works automatically in the background',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'We need "Allow all the time" location access to detect when you enter or leave mosque areas, even when your phone is locked.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Visual flow
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildFlowStep(
                  Icons.directions_walk,
                  'Walking to mosque',
                  'App detects your location',
                  const Color(0xFF07828A),
                ),
                const SizedBox(height: 16),
                _buildFlowStep(
                  Icons.volume_off,
                  'Phone goes silent',
                  'Automatically when you enter',
                  Colors.red,
                ),
                const SizedBox(height: 16),
                _buildFlowStep(
                  Icons.volume_up,
                  'Sound returns',
                  'When you leave the mosque',
                  Colors.green,
                ),
              ],
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.blue.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your location is never stored or shared. We only use it to check if you\'re near a mosque.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          Text(
            '🔔 Notifications',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Stay informed about your phone\'s status',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Get notified when your phone switches to silent mode and when it returns to normal.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildNotificationExample(
                  '🔇 Silent Mode On',
                  'Your phone is silenced for the mosque',
                  Colors.red.withOpacity(0.2),
                ),
                const SizedBox(height: 12),
                _buildNotificationExample(
                  '🔊 Normal Mode Restored',
                  'You are outside mosque zones. Calls and alerts are back on.',
                  Colors.green.withOpacity(0.2),
                ),
              ],
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is optional but recommended. You can always enable notifications later in Settings.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDndPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          Text(
            '🔕 Do Not Disturb Access',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Required for automatic silencing',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'This permission allows MosqueSilence to automatically change your phone\'s ringer mode when entering or leaving mosque areas.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildFlowStep(
                  Icons.mosque,
                  'Enter mosque area',
                  'Phone automatically goes silent',
                  const Color(0xFF07828A),
                ),
                const SizedBox(height: 16),
                _buildFlowStep(
                  Icons.volume_up,
                  'Leave mosque area',
                  'Normal ringer mode restored',
                  Colors.green,
                ),
              ],
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Without this permission, the app cannot function properly. It\'s required for automatic ringer control.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF07828A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF07828A).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF07828A),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'You\'re all set!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'MosqueSilence will now automatically silence your phone at mosques and restore normal sound when you leave.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Quick Tips:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTip('Toggle the service on/off from the main screen'),
                _buildTip('Add your own mosque locations in Settings'),
                _buildTip(
                  'We automatically include nearby mosques from our catalog',
                ),
                _buildTip(
                  'Turn off DND when you want automatic ringer changes to work',
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFlowStep(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationExample(String title, String body, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    String buttonText;
    VoidCallback? onPressed;

    switch (_currentPage) {
      case 0:
        buttonText = _isRequesting ? 'Requesting...' : 'Allow Location';
        onPressed = _isRequesting ? null : _requestLocationPermission;
        break;
      case 1:
        buttonText = _isRequesting ? 'Requesting...' : 'Allow Notifications';
        onPressed = _isRequesting ? null : _requestNotificationPermission;
        break;
      case 2:
        buttonText = _isRequesting ? 'Requesting...' : 'Grant DND Permission';
        onPressed = _isRequesting ? null : _requestDndPermission;
        break;
      case 3:
        buttonText = 'Get Started';
        onPressed = widget.onComplete;
        break;
      default:
        buttonText = 'Next';
        onPressed = _nextPage;
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: _isRequesting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(
              _currentPage == 3
                  ? Icons.check
                  : (_currentPage == 2
                        ? Icons.do_not_disturb_on
                        : Icons.arrow_forward),
            ),
      label: Text(buttonText),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF07828A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Add skip button for the DND page
  Widget _buildSkipButton() {
    if (_currentPage != 2)
      return const SizedBox.shrink(); // Only show on DND page

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: _isRequesting ? null : _nextPage,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Skip DND Permission'),
      ),
    );
  }
}
