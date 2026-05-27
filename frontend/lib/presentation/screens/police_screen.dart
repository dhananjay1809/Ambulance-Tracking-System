import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/socket_io_service.dart';

// Helper method to get connection status color
Color _getConnectionStatusColor(ConnectionStatus status) {
  switch (status) {
    case ConnectionStatus.connected:
      return Colors.greenAccent;
    case ConnectionStatus.connecting:
      return Colors.orangeAccent;
    case ConnectionStatus.error:
      return Colors.redAccent;
    case ConnectionStatus.disconnected:
      return Colors.grey;
  }
}

// Helper method to get connection status text
String _getConnectionStatusText(ConnectionStatus status) {
  switch (status) {
    case ConnectionStatus.connected:
      return 'CONNECTED';
    case ConnectionStatus.connecting:
      return 'CONNECTING...';
    case ConnectionStatus.error:
      return 'ERROR';
    case ConnectionStatus.disconnected:
      return 'DISCONNECTED';
  }
}

class PoliceScreen extends StatefulWidget {
  final String userId;
  const PoliceScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _PoliceScreenState createState() => _PoliceScreenState();
}

class _PoliceScreenState extends State<PoliceScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late SocketService _socketService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- State Variables ---
  LatLng _currentBaseLocation = const LatLng(20.9374, 77.7796); 
  final TextEditingController _baseLocationController = TextEditingController();
  final Map<String, AmbulancePosition> _activeAmbulances = {};
  ProximityAlert? _currentAlert;
  static const double _alertRadiusInKm = 2.5;
  
  // --- NEW: Statistics tracking ---
  int _alertCount = 0;
  DateTime? _dutyStartTime;
  double? _distanceToNearestAmbulance;

  // --- Animation Controllers ---
  late AnimationController _alertAnimController;
  late Animation<Offset> _alertSlideAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _alertTimer;
  Timer? _policeLocationTimer;

  // --- Amravati Coordinates Database ---
  final Map<String, LatLng> _amravatiCoordinates = {
    'Amravati Railway Station': const LatLng(20.9320, 77.7523),
    'Rajkamal Square': const LatLng(20.9374, 77.7796),
    'Kathora Gate': const LatLng(20.9968, 77.7565),
    'Camp Area': const LatLng(20.9436, 77.7617),
    'Irwin Square': const LatLng(20.9275, 77.7580),
    'Badnera Station': const LatLng(20.8600, 77.7300),
    'Sai Nagar': const LatLng(20.9000, 77.7300),
  };

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);
    _dutyStartTime = DateTime.now();

    // Setup animations
    _alertAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _alertSlideAnim = Tween<Offset>(begin: const Offset(0, -2.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _alertAnimController, curve: Curves.easeOutBack));

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 3.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    _pulseController.repeat(reverse: true);

    _connectAndListen();
    _getInitialLocation();
    
    // Send police location updates every 10 seconds
    _policeLocationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _socketService.updatePoliceLocation(_currentBaseLocation);
    });
  }

  void _connectAndListen() {
    print('[PoliceScreen] Connecting with userId: ${widget.userId}, role: police, location: $_currentBaseLocation');
    _socketService.connectAndListen(userId: widget.userId, role: 'police', location: _currentBaseLocation);
    
    _socketService.positionUpdateStream.listen((pos) {
      print('[PoliceScreen] 📍 RECEIVED AMBULANCE UPDATE: ${pos.ambulanceId} at (${pos.lat}, ${pos.lng})');
      if (mounted) {
        setState(() => _activeAmbulances[pos.ambulanceId] = pos);
        _updateDistanceToNearest();
        print('[PoliceScreen] Active ambulances count: ${_activeAmbulances.length}');
      }
    }, onError: (e) {
      print('[PoliceScreen] Position stream error: $e');
    });
    
    _socketService.alertStream.listen((alert) {
      print('[PoliceScreen] 🚨 ALERT RECEIVED: ${alert.message}');
      _triggerAlert(alert);
    }, onError: (e) {
      print('[PoliceScreen] Alert stream error: $e');
    });
  }

  void _updateDistanceToNearest() {
    if (_activeAmbulances.isEmpty) {
      _distanceToNearestAmbulance = null;
      return;
    }
    
    final distance = const Distance();
    double? minDist;
    
    for (var amb in _activeAmbulances.values) {
      final d = distance.as(LengthUnit.Kilometer, _currentBaseLocation, LatLng(amb.lat, amb.lng));
      if (minDist == null || d < minDist) minDist = d;
    }
    
    setState(() => _distanceToNearestAmbulance = minDist);
  }

  Future<void> _getInitialLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS is disabled. Please enable location services.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Enable in settings.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Try high accuracy first, fallback to low
      Position p;
      try {
        p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
      }
      
      if (mounted) {
        _setNewBaseLocation(
          LatLng(p.latitude, p.longitude),
          'My Current Location'
        );
      }
    } catch (e) {
      print('Police GPS acquisition failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS failed: $e. Using default location.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _triggerAlert(ProximityAlert alert) async {
    if (!mounted) return;

    _alertCount++; // Track alert count
    print('[PoliceScreen] ⚠️ ALERT TRIGGERED: ${alert.message}');

    // Physical feedback - improved with stronger vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      print('[PoliceScreen] Has vibrator: $hasVibrator');
      
      if (hasVibrator == true) {
        // Use a stronger vibration pattern: [wait, vibrate, pause, vibrate, pause, vibrate]
        // Pattern: 0ms wait, 800ms vibrate, 200ms pause, 800ms vibrate, 200ms pause, 800ms vibrate
        await Vibration.vibrate(pattern: [0, 800, 200, 800, 200, 800], intensities: [0, 255, 0, 255, 0, 255]);
        print('[PoliceScreen] Vibration triggered with pattern');
      }
      
      // Also try amplitude-based vibration as fallback
      if (hasVibrator == true) {
        final hasAmplitude = await Vibration.hasAmplitudeControl();
        print('[PoliceScreen] Has amplitude control: $hasAmplitude');
        if (hasAmplitude == true) {
          await Vibration.vibrate(duration: 1000, amplitude: 255);
        }
      }
    } catch (e) {
      print('[PoliceScreen] Vibration error: $e');
    }

    // Sound feedback
    try { 
      await _audioPlayer.play(AssetSource('sounds/siren.mp3')); 
      print('[PoliceScreen] Playing alert sound');
    } catch (e) {
      print('[PoliceScreen] Audio error: $e');
    }

    // Visual feedback
    setState(() => _currentAlert = alert);
    _alertAnimController.forward(from: 0.0);
    
    final pos = _activeAmbulances[alert.ambulanceId];
    if (pos != null) _mapController.move(LatLng(pos.lat, pos.lng), 15.0);

    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) { _alertAnimController.reverse(); _audioPlayer.stop(); }
    });
  }

  void _setNewBaseLocation(LatLng newLocation, String locationName) {
    setState(() {
      _currentBaseLocation = newLocation;
      _baseLocationController.text = locationName;
    });
    _mapController.move(newLocation, 14.5);
    _socketService.updatePoliceLocation(newLocation);
    _updateDistanceToNearest();
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  Color _getMarkerColor(double distanceKm) {
    if (distanceKm < 0.5) return Colors.red;
    if (distanceKm < 1.0) return Colors.orange;
    if (distanceKm < 2.0) return Colors.yellow[700]!;
    return Colors.green;
  }

  String _getDutyDuration() {
    if (_dutyStartTime == null) return '00:00';
    final duration = DateTime.now().difference(_dutyStartTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _focusOnAmbulance(AmbulancePosition amb) {
    _mapController.move(LatLng(amb.lat, amb.lng), 16.0);
  }

  @override
  void dispose() {
    _alertAnimController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _alertTimer?.cancel();
    _policeLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: Stack(
        children: [
          // 1. MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentBaseLocation, initialZoom: 14.5),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'com.ats.ambulancetracker'),

              // 2. ANIMATED PULSE ZONE
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _currentBaseLocation,
                        radius: _alertRadiusInKm * 1000,
                        useRadiusInMeter: true,
                        color: Colors.blueAccent.withOpacity(0.1 - (_pulseController.value * 0.05)),
                        borderColor: Colors.blueAccent,
                        borderStrokeWidth: _pulseAnimation.value,
                      ),
                    ],
                  );
                },
              ),

              // 3. MARKERS
              MarkerLayer(
                markers: [
                  // Radar sweep
                  Marker(
                    point: _currentBaseLocation,
                    width: 250, height: 250,
                    child: Opacity(
                      opacity: 0.3,
                      child: Lottie.network(
                        'https://lottie.host/57398313-9776-4b33-9c4b-e03170975b6a/Look7G6e0V.json',
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.radar, color: Colors.blueAccent, size: 80);
                        },
                      ),
                    ),
                  ),
                  // Police HQ
                  Marker(
                    point: _currentBaseLocation,
                    width: 65, height: 65,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        color: Colors.blue[900], 
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 15)]
                      ),
                      child: const Icon(Icons.security, color: Colors.white, size: 35),
                    ),
                  ),
                  // Ambulances with distance indicators
                  ..._activeAmbulances.values.map((data) {
                    final dist = _calculateDistance(_currentBaseLocation, LatLng(data.lat, data.lng));
                    final color = _getMarkerColor(dist);
                    
                    return Marker(
                      point: LatLng(data.lat, data.lng),
                      width: 80, height: 90,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Distance label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              '${dist.toStringAsFixed(1)}km',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Ambulance icon
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.2),
                            ),
                            child: Transform.rotate(
                              angle: (data.heading ?? 0) * (math.pi / 180),
                              child: SvgPicture.asset('assets/images/ambulance_marker.svg'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          // 4. ENHANCED STATISTICS DASHBOARD
          Positioned(
            top: 135, left: 15, right: 15,
            child: _buildEnhancedStatsWidget(),
          ),

          // 5. ALERT BANNER
          if (_currentAlert != null) 
            Positioned(
              top: 235, left: 15, right: 15,
              child: _buildAlertBanner(),
            ),

          // 6. ACTIVE AMBULANCES LIST (Bottom Sheet)
          if (_activeAmbulances.isNotEmpty)
            _buildAmbulanceListSheet(),

          // 7. MAP CONTROLS
          Positioned(
            right: 15,
            bottom: 180,
            child: _buildMapControls(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(100.0),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 10),
            child: Card(
              color: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // GPS button to use current location
                    InkWell(
                      onTap: _fetchAndSetCurrentLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(border: InputBorder.none),
                        hint: const Text("Set Base Location"),
                        items: _amravatiCoordinates.keys.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) { if (val != null) _setNewBaseLocation(_amravatiCoordinates[val]!, val); },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fetch current GPS location and set as base location
  Future<void> _fetchAndSetCurrentLocation() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Fetching GPS location...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable GPS.'), backgroundColor: Colors.red),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied'), backgroundColor: Colors.red),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied'), backgroundColor: Colors.red),
        );
        return;
      }

      // Try high accuracy first, fallback to low
      Position p;
      try {
        p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
      }
      
      if (mounted) {
        _setNewBaseLocation(
          LatLng(p.latitude, p.longitude),
          'My GPS Location'
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set: ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Police GPS acquisition failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get GPS: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildEnhancedStatsWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D1B2A), const Color(0xFF1B263B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 2),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Connection status indicator
                  Consumer<SocketService>(
                    builder: (context, socketService, _) {
                      final status = socketService.connectionStatus;
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getConnectionStatusColor(status),
                          boxShadow: status == ConnectionStatus.connected
                            ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 6)]
                            : null,
                        ),
                      );
                    },
                  ),
                  const Icon(Icons.radar, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Consumer<SocketService>(
                    builder: (context, socketService, _) {
                      final status = socketService.connectionStatus;
                      return Text(
                        status == ConnectionStatus.connected ? "LIVE MONITORING" : _getConnectionStatusText(status),
                        style: TextStyle(
                          color: _getConnectionStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(20)),
                child: Text("ON DUTY ${_getDutyDuration()}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.local_hospital, '${_activeAmbulances.length}', 'Active', Colors.blueAccent),
              _buildStatItem(Icons.notifications_active, '$_alertCount', 'Alerts', Colors.orangeAccent),
              _buildStatItem(Icons.near_me, _distanceToNearestAmbulance != null ? '${_distanceToNearestAmbulance!.toStringAsFixed(1)}km' : '--', 'Nearest', Colors.purpleAccent),
              _buildStatItem(Icons.radar, '${_alertRadiusInKm}km', 'Radius', Colors.cyanAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildAlertBanner() {
    return SlideTransition(
      position: _alertSlideAnim,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[900],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20)],
          border: Border.all(color: Colors.yellow, width: 2),
        ),
        child: Row(
          children: [
            Lottie.network(
              'https://lottie.host/8e2f83f2-8951-40c0-9366-267389658742/vX7G7G6e0V.json',
              width: 40, height: 40,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.warning_amber, color: Colors.yellow, size: 40);
              },
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("⚠️ PROXIMITY BREACH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_currentAlert!.message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop_circle, color: Colors.white, size: 18),
              label: const Text("STOP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                setState(() => _currentAlert = null);
                _alertAnimController.reverse();
                _audioPlayer.stop();
                _alertTimer?.cancel();
                Vibration.cancel();
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAmbulanceListSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.08,
      maxChildSize: 0.5,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(blurRadius: 15, color: Colors.black26, offset: const Offset(0, -4))],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Ambulances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                      child: Text('${_activeAmbulances.length} Units', style: TextStyle(color: Colors.red[900], fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _activeAmbulances.length,
                  itemBuilder: (context, i) {
                    final ambulance = _activeAmbulances.values.elementAt(i);
                    final distance = _calculateDistance(_currentBaseLocation, LatLng(ambulance.lat, ambulance.lng));
                    final color = _getMarkerColor(distance);
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.2),
                        child: Icon(Icons.local_hospital, color: color, size: 20),
                      ),
                      title: Text('Ambulance ${ambulance.ambulanceId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${distance.toStringAsFixed(2)} km away'),
                      trailing: IconButton(
                        icon: const Icon(Icons.center_focus_strong, color: Colors.blue),
                        onPressed: () => _focusOnAmbulance(ambulance),
                        tooltip: 'Center on map',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapControls() {
    return Column(
      children: [
        // Scan for ambulances button
        FloatingActionButton.small(
          heroTag: 'scan',
          backgroundColor: Colors.purple,
          onPressed: () {
            print('[PoliceScreen] 📡 Scanning for ambulances...');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Scanning for ambulances...'),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
            
            _socketService.scanAmbulances(onResult: (ambulances) {
              if (mounted) {
                for (var amb in ambulances) {
                  setState(() => _activeAmbulances[amb.ambulanceId] = amb);
                }
                _updateDistanceToNearest();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Found ${ambulances.length} active ambulances'),
                    backgroundColor: ambulances.isNotEmpty ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            });
          },
          tooltip: 'Scan for Ambulances',
          child: const Icon(Icons.radar, color: Colors.white),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoomIn',
          backgroundColor: Colors.white,
          onPressed: () {
            final currentZoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, currentZoom + 1);
          },
          child: const Icon(Icons.add, color: Colors.black),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoomOut',
          backgroundColor: Colors.white,
          onPressed: () {
            final currentZoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, currentZoom - 1);
          },
          child: const Icon(Icons.remove, color: Colors.black),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'center',
          backgroundColor: Colors.blueAccent,
          onPressed: () {
            _mapController.move(_currentBaseLocation, 15.0);
          },
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
        const SizedBox(height: 8),
        // Test vibration button
        FloatingActionButton.small(
          heroTag: 'testVibration',
          backgroundColor: Colors.orange,
          onPressed: () async {
            try {
              final hasVibrator = await Vibration.hasVibrator();
              print('[PoliceScreen] Test: Has vibrator: $hasVibrator');
              
              if (hasVibrator == true) {
                await Vibration.vibrate(duration: 500, amplitude: 255);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vibration triggered!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No vibrator on this device'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                );
              }
            } catch (e) {
              print('[PoliceScreen] Vibration test error: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Vibration error: $e'), backgroundColor: Colors.red),
              );
            }
          },
          tooltip: 'Test Vibration',
          child: const Icon(Icons.vibration, color: Colors.white),
        ),
        const SizedBox(height: 8),
        // Reconnect button
        FloatingActionButton.small(
          heroTag: 'reconnect',
          backgroundColor: Colors.green,
          onPressed: () async {
            print('[PoliceScreen] Manual reconnect triggered');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reconnecting to server...'), duration: Duration(seconds: 1)),
            );
            
            // Disconnect and reconnect
            _socketService.disconnect();
            await Future.delayed(const Duration(milliseconds: 500));
            _socketService.connectAndListen(
              userId: widget.userId, 
              role: 'police', 
              location: _currentBaseLocation
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reconnected! Ready to receive updates.'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
            );
          },
          tooltip: 'Reconnect',
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
    );
  }
}
