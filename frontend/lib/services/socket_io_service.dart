import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:latlong2/latlong.dart';

// --- DATA MODELS ---
class AmbulancePosition {
  final String ambulanceId;
  final double lat;
  final double lng;
  final double? heading;

  AmbulancePosition({
    required this.ambulanceId, 
    required this.lat, 
    required this.lng,
    this.heading,
  });

  factory AmbulancePosition.fromJson(Map<String, dynamic> json) {
    return AmbulancePosition(
      ambulanceId: json['ambulanceId'] ?? json['driverId'] ?? 'unknown',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
    );
  }
}

class ProximityAlert {
  final String ambulanceId;
  final String message;

  ProximityAlert({
    required this.ambulanceId, 
    required this.message
  });

  factory ProximityAlert.fromJson(Map<String, dynamic> json) {
    return ProximityAlert(
      ambulanceId: json['ambulanceId'] ?? 'unknown',
      message: json['message'] ?? 'Ambulance is approaching!',
    );
  }
}

// --- CONNECTION STATUS ENUM ---
enum ConnectionStatus { disconnected, connecting, connected, error }

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  
  // --- Configurable Socket URL ---
  // Default to deployed Render.com backend - no configuration needed!
  static const String _defaultSocketUrl = 'https://final-year-app.onrender.com';
  String _currentSocketUrl = _defaultSocketUrl;

  // --- Connection Status Tracking ---
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? _lastError;
  String? get lastError => _lastError;

  // --- User/Role for reconnection ---
  String? _currentUserId;
  String? _currentRole;
  LatLng? _currentLocation;

  // --- STREAMS ---
  final StreamController<AmbulancePosition> _positionUpdateController = StreamController.broadcast();
  Stream<AmbulancePosition> get positionUpdateStream => _positionUpdateController.stream;

  final StreamController<ProximityAlert> _alertController = StreamController.broadcast();
  Stream<ProximityAlert> get alertStream => _alertController.stream;

  bool get isConnected => _socket?.connected ?? false;

  SocketService() {
    _loadSocketUrl();
  }

  /// Load socket URL from SharedPreferences
  Future<void> _loadSocketUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSocketUrl = prefs.getString('socket_url') ?? _defaultSocketUrl;
    debugPrint('[SocketService] Loaded socket URL: $_currentSocketUrl');
  }

  /// Save and update socket URL
  static Future<void> setSocketUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('socket_url', url);
    debugPrint('[SocketService] Saved socket URL: $url');
  }

  /// Get current socket URL
  static Future<String> getSocketUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('socket_url') ?? _defaultSocketUrl;
  }

  void _updateConnectionStatus(ConnectionStatus status, {String? error}) {
    _connectionStatus = status;
    _lastError = error;
    notifyListeners();
    debugPrint('[SocketService] Connection status: $status ${error != null ? "($error)" : ""}');
  }

  void _initSocket() {
    // Dispose existing socket if any
    _socket?.dispose();

    debugPrint('[SocketService] Initializing socket to: $_currentSocketUrl');
    _updateConnectionStatus(ConnectionStatus.connecting);

    _socket = IO.io(_currentSocketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 2000,
    });

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Socket connected: ${_socket!.id}');
      _updateConnectionStatus(ConnectionStatus.connected);
      
      // --- FIX: Always send join event with location on connect/reconnect ---
      if (_currentUserId != null && _currentRole != null) {
        final joinPayload = <String, dynamic>{
          'userId': _currentUserId!,
          'role': _currentRole!,
        };
        if (_currentLocation != null) {
          joinPayload['location'] = {
            'lat': _currentLocation!.latitude,
            'lng': _currentLocation!.longitude
          };
        }
        _socket!.emit('join', joinPayload);
        debugPrint('[SocketService] Emitted join event: $joinPayload');
        
        // --- FIX: For police, also send location update immediately ---
        if (_currentRole == 'police' && _currentLocation != null) {
          _socket!.emit('updatePoliceLocation', {
            'userId': _currentUserId,
            'lat': _currentLocation!.latitude,
            'lng': _currentLocation!.longitude,
          });
          debugPrint('[SocketService] Sent initial police location');
        }
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Socket disconnected');
      _updateConnectionStatus(ConnectionStatus.disconnected);
    });

    _socket!.onError((data) {
      debugPrint('[SocketService] Socket Error: $data');
      _updateConnectionStatus(ConnectionStatus.error, error: data.toString());
    });

    _socket!.onConnectError((data) {
      debugPrint('[SocketService] Connection Error: $data');
      _updateConnectionStatus(ConnectionStatus.error, error: 'Connection failed: $data');
    });

    _socket!.onReconnect((_) {
      debugPrint('[SocketService] Socket reconnected');
      _updateConnectionStatus(ConnectionStatus.connected);
    });

    // --- LISTENERS FOR INCOMING EVENTS ---
    _socket!.on('ambulancePositionUpdate', (data) {
      try {
        debugPrint('[SocketService] Received position update: $data');
        _positionUpdateController.add(AmbulancePosition.fromJson(data));
      } catch (e) {
        debugPrint('[SocketService] Error parsing ambulancePositionUpdate: $e');
      }
    });

    _socket!.on('ambulanceProximityAlert', (data) {
      try {
        debugPrint('[SocketService] ⚠️ ALERT RECEIVED: $data');
        _alertController.add(ProximityAlert.fromJson(data));
      } catch (e) {
        debugPrint('[SocketService] Error parsing proximityAlert: $e');
      }
    });
  }

  // --- PUBLIC METHODS ---
  Future<void> connectAndListen({required String userId, required String role, LatLng? location}) async {
    // Store for reconnection
    _currentUserId = userId;
    _currentRole = role;
    _currentLocation = location;

    // Reload URL in case it changed
    await _loadSocketUrl();
    
    // Initialize with current URL
    _initSocket();

    // Get token and connect
    final token = await AuthService.getToken();
    if (token != null) {
      final options = _socket!.io.options as Map<String, dynamic>;
      options['auth'] = {'token': token};
    }
    
    _socket!.connect();
  }

  /// Reconnect with a new server URL
  Future<void> reconnectWithUrl(String newUrl) async {
    await setSocketUrl(newUrl);
    _currentSocketUrl = newUrl;
    
    if (_currentUserId != null && _currentRole != null) {
      await connectAndListen(
        userId: _currentUserId!,
        role: _currentRole!,
        location: _currentLocation
      );
    }
  }

  /// Updated for Driver Screen to send rotation and userId
  void sendLocationUpdate({
    required String ambulanceId, 
    required double lat, 
    required double lng,
    double? heading,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('[SocketService] Cannot send location: socket not connected');
      return;
    }
    final payload = {
      'ambulanceId': ambulanceId,
      'userId': ambulanceId, // Include userId for backend tracking
      'lat': lat,
      'lng': lng,
      'heading': heading,
    };
    _socket!.emit('updateLocation', payload);
    debugPrint('[SocketService] Sent location update: $payload');
  }

  void updatePoliceLocation(LatLng location) {
    _currentLocation = location; // Store for reconnection
    
    if (_socket == null || !_socket!.connected) {
      debugPrint('[SocketService] Cannot update police location: socket not connected');
      return;
    }
    final payload = {
      'userId': _currentUserId,
      'lat': location.latitude,
      'lng': location.longitude,
    };
    _socket!.emit('updatePoliceLocation', payload);
    debugPrint('[SocketService] Updated police location: $payload');
  }

  /// Scan for active ambulances in the area
  void scanAmbulances({Function(List<AmbulancePosition>)? onResult}) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('[SocketService] Cannot scan: socket not connected');
      onResult?.call([]);
      return;
    }
    
    debugPrint('[SocketService] 📡 Scanning for active ambulances...');
    
    // Listen for scan result
    _socket!.once('scanResult', (data) {
      debugPrint('[SocketService] Scan result received: $data');
      try {
        if (data['success'] == true && data['ambulances'] != null) {
          final List<dynamic> ambulances = data['ambulances'];
          final List<AmbulancePosition> positions = ambulances
              .map((a) => AmbulancePosition.fromJson(a))
              .toList();
          
          // Add each to the position stream so they show on map
          for (var pos in positions) {
            _positionUpdateController.add(pos);
          }
          
          onResult?.call(positions);
          debugPrint('[SocketService] ✓ Found ${positions.length} ambulances');
        } else {
          debugPrint('[SocketService] Scan returned no results or failed');
          onResult?.call([]);
        }
      } catch (e) {
        debugPrint('[SocketService] Error parsing scan result: $e');
        onResult?.call([]);
      }
    });
    
    // Send scan request
    _socket!.emit('scanAmbulances', {});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _updateConnectionStatus(ConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    _positionUpdateController.close();
    _alertController.close();
    _socket?.dispose();
    super.dispose();
  }
}