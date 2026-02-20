// lib/screens/live_map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../services/firebase_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController mapController = MapController();
  final LatLng defaultCenter = const LatLng(51.505, -0.09);
  LatLng? currentLocation;

  String layerType = 'standard';
  bool showTrails = false;
  bool showHeatmap = false;
  bool showRoutes = false;
  bool showGeofences = false;
  bool plumeOn = false;
  String incidentSeverity = 'critical';
  String incidentNote = '';
  bool incidentMode = false;
  String timelineFilter = 'all';
  bool notificationSoundOn = true;
  List<IncidentMarker> incidentMarkers = [];

  // Drone positions
  LatLng dronePosition = const LatLng(51.505, -0.09);
  LatLng drone2Position = const LatLng(51.505, -0.09);
  LatLng drone3Position = const LatLng(51.505, -0.09);
  LatLng drone4Position = const LatLng(51.505, -0.09);
  LatLng drone5Position = const LatLng(51.505, -0.09);

  // Drone path variables
  List<LatLng> dronePath = [];
  int currentPathIndex = 0;
  Timer? _pathTimer;

  List<LatLng> drone2Path = [];
  int drone2PathIndex = 0;

  List<LatLng> drone3Path = [];
  int drone3PathIndex = 0;

  List<LatLng> drone4Path = [];
  int drone4PathIndex = 0;

  List<LatLng> drone5Path = [];
  int drone5PathIndex = 0;

  // Hazardous zones
  HazardousZone? redZone;
  HazardousZone? greenZone;
  HazardousZone? mediumRiskZone;
  HazardousZone? lowRiskZone;

  // Drone data
  final List<Drone> drones = [];
  StreamSubscription<Map<String, dynamic>>? _droneSubscription;
  
  // Hazardous zones data
  final List<HazardousZone> hazardousZones = [];
  StreamSubscription<Map<String, dynamic>>? _zonesSubscription;

  final List<AlertItem> alertTimelineData = [
    AlertItem(id: 1, severity: 'critical', message: 'Chlorine plume detected', time: '00:00:32'),
    AlertItem(id: 2, severity: 'high', message: 'Biological sample positive', time: '00:01:18'),
    AlertItem(id: 3, severity: 'medium', message: 'Radiological spike', time: '00:02:52'),
    AlertItem(id: 4, severity: 'low', message: 'Wind shift detected', time: '00:03:44'),
  ];

  final List<NotificationItem> notifications = [
    NotificationItem(id: 1, message: 'Perimeter sensor triggered', time: '00:01:04'),
    NotificationItem(id: 2, message: 'Team Bravo entered decon', time: '00:02:20'),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToDroneUpdates();
    _listenToZoneUpdates();
  }

  void _listenToDroneUpdates() {
    _droneSubscription = FirebaseService().getDronePositions().listen((dronesData) {
      if (dronesData.isEmpty) return;
      
      setState(() {
        drones.clear();
        dronesData.forEach((key, value) {
          final droneData = Map<String, dynamic>.from(value);
          final droneId = droneData['id'] ?? 0;
          final position = LatLng(
            (droneData['lat'] ?? 0.0).toDouble(),
            (droneData['lng'] ?? 0.0).toDouble(),
          );
          
          drones.add(Drone(
            id: droneId,
            name: droneData['name'] ?? 'Unknown',
            position: position,
            status: droneData['status'] ?? 'Unknown',
            battery: droneData['battery'] ?? 0,
          ));

          // Update individual drone position variables based on drone ID
          switch (droneId) {
            case 1:
              dronePosition = position;
              break;
            case 2:
              drone2Position = position;
              break;
            case 3:
              drone3Position = position;
              break;
            case 4:
              drone4Position = position;
              break;
            case 5:
              drone5Position = position;
              break;
          }
        });
      });
    });
  }

  void _listenToZoneUpdates() {
    _zonesSubscription = FirebaseService().getHazardousZones().listen((zonesData) {
      if (zonesData.isEmpty) return;
      
      setState(() {
        hazardousZones.clear();
        zonesData.forEach((key, value) {
          final zoneData = Map<String, dynamic>.from(value);
          hazardousZones.add(HazardousZone(
            name: zoneData['name'] ?? 'Unknown Zone',
            center: LatLng(
              (zoneData['lat'] ?? 0.0).toDouble(),
              (zoneData['lng'] ?? 0.0).toDouble(),
            ),
            radiusKm: (zoneData['radiusKm'] ?? 0.3).toDouble(),
            severity: zoneData['severity'] ?? 'medium',
            substanceType: zoneData['substanceType'] ?? 'unknown',
            detected: zoneData['detected'] ?? false,
          ));
        });
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final userLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      currentLocation = userLocation;
      // Move map to user's location
      mapController.move(userLocation, 16.0);
      
      // Create red zone (dangerous) on drone's path - northeast
      redZone = HazardousZone(
        name: 'Chemical Hazard Zone',
        center: LatLng(userLocation.latitude + 0.003, userLocation.longitude + 0.003),
        radiusKm: 0.3,
        severity: 'critical',
        substanceType: 'chemical',
        detected: false,
      );

      // Create green zone (safe) further away from red zone - far northeast
      greenZone = HazardousZone(
        name: 'Safe Zone',
        center: LatLng(userLocation.latitude + 0.008, userLocation.longitude + 0.008),
        radiusKm: 0.3,
        severity: 'safe',
        substanceType: 'none',
        detected: false,
      );

      // Create low risk zone (yellow) - southwest
      lowRiskZone = HazardousZone(
        name: 'Low Risk Zone',
        center: LatLng(userLocation.latitude - 0.003, userLocation.longitude - 0.003),
        radiusKm: 0.3,
        severity: 'low',
        substanceType: 'mild_chemical',
        detected: false,
      );

      // Create high risk zone (orange) - southeast
      mediumRiskZone = HazardousZone(
        name: 'High Risk Zone',
        center: LatLng(userLocation.latitude - 0.003, userLocation.longitude + 0.003),
        radiusKm: 0.3,
        severity: 'high',
        substanceType: 'hazardous_chemical',
        detected: false,
      );
    });

    // Initialize drone positions (animation controlled by overview screen)
    _initializeDronePositions(userLocation);
  }

  void _initializeDronePositions(LatLng userLocation) {
    // Set initial drone positions around user's location
    dronePosition = LatLng(userLocation.latitude + 0.002, userLocation.longitude + 0.002);
    drone2Position = LatLng(userLocation.latitude - 0.002, userLocation.longitude - 0.002);
    drone3Position = LatLng(userLocation.latitude + 0.004, userLocation.longitude + 0.004);
    drone4Position = LatLng(userLocation.latitude - 0.004, userLocation.longitude + 0.004);
    drone5Position = LatLng(userLocation.latitude + 0.004, userLocation.longitude - 0.004);
  }

  void _initializeDrones(LatLng userLocation) {
    // Create 5 drones around user's location
    // Drone 1: ~500m northeast
    final drone1 = Drone(
      id: 1,
      name: 'Drone Alpha',
      position: LatLng(userLocation.latitude + 0.0045, userLocation.longitude + 0.0045),
      status: 'Active',
      battery: 85,
    );

    // Drone 2: ~500m southwest
    final drone2 = Drone(
      id: 2,
      name: 'Drone Bravo',
      position: LatLng(userLocation.latitude - 0.0045, userLocation.longitude - 0.0045),
      status: 'Active',
      battery: 72,
    );

    // Drone 3: ~500m northwest
    final drone3 = Drone(
      id: 3,
      name: 'Drone Charlie',
      position: LatLng(userLocation.latitude + 0.0045, userLocation.longitude - 0.0045),
      status: 'Active',
      battery: 90,
    );

    // Drone 4: ~500m southeast
    final drone4 = Drone(
      id: 4,
      name: 'Drone Delta',
      position: LatLng(userLocation.latitude - 0.0045, userLocation.longitude + 0.0045),
      status: 'Active',
      battery: 78,
    );

    // Drone 5: ~600m east
    final drone5 = Drone(
      id: 5,
      name: 'Drone Echo',
      position: LatLng(userLocation.latitude, userLocation.longitude + 0.006),
      status: 'Active',
      battery: 88,
    );

    drones.clear();
    drones.addAll([drone1, drone2, drone3, drone4, drone5]);
  }

  List<LatLng> _generatePath(String pattern, LatLng center, {int offsetIndex = 0}) {
    List<LatLng> path = [];
    final double latStep = 0.001;
    final double lngStep = 0.001;

    // Offset based on drone index (creates different paths for each drone)
    final double offsetLat = offsetIndex * 0.002;
    final double offsetLng = offsetIndex * 0.002;

    switch (pattern) {
      case 'Grid':
        // Grid pattern - back and forth
        if (offsetIndex % 2 == 1) {
          // Odd index drones - different grid pattern (vertical instead of horizontal)
          for (int i = 0; i < 5; i++) {
            path.add(LatLng(center.latitude + offsetLat, center.longitude + i * lngStep + offsetLng));
            path.add(LatLng(center.latitude + 4 * latStep + offsetLat, center.longitude + i * lngStep + offsetLng));
            if (i < 4) {
              path.add(LatLng(center.latitude + 4 * latStep + offsetLat, center.longitude + (i + 1) * lngStep + offsetLng));
              path.add(LatLng(center.latitude + offsetLat, center.longitude + (i + 1) * lngStep + offsetLng));
            }
          }
        } else {
          // Even index drones - horizontal grid
          for (int i = 0; i < 5; i++) {
            path.add(LatLng(center.latitude + i * latStep + offsetLat, center.longitude + offsetLng));
            path.add(LatLng(center.latitude + i * latStep + offsetLat, center.longitude + 4 * lngStep + offsetLng));
            if (i < 4) {
              path.add(LatLng(center.latitude + (i + 1) * latStep + offsetLat, center.longitude + 4 * lngStep + offsetLng));
              path.add(LatLng(center.latitude + (i + 1) * latStep + offsetLat, center.longitude + offsetLng));
            }
          }
        }
        break;
      case 'Spiral':
        // Spiral pattern - expanding circle
        for (int i = 0; i < 50; i++) {
          double angle = (offsetIndex % 2 == 1 ? -1 : 1) * i * 0.3;
          double radius = 0.002 + (i * 0.0003);
          path.add(LatLng(
            center.latitude + radius * math.cos(angle) + offsetLat,
            center.longitude + radius * math.sin(angle) + offsetLng,
          ));
        }
        break;
      case 'Random':
        // Random pattern - pseudo random waypoints
        path.add(LatLng(center.latitude + offsetLat, center.longitude + offsetLng));
        for (int i = 0; i < 20; i++) {
          if (offsetIndex % 2 == 1) {
            // Odd index drones - different random pattern
            path.add(LatLng(
              center.latitude + (i * 0.0005) + (i % 2 == 0 ? 0.003 : -0.002) + offsetLat,
              center.longitude + (i * 0.0005) + (i % 3 == 0 ? -0.003 : 0.002) + offsetLng,
            ));
          } else {
            // Even index drones - normal random
            path.add(LatLng(
              center.latitude + (i * 0.0005) + (i % 3 == 0 ? 0.002 : -0.001) + offsetLat,
              center.longitude + (i * 0.0005) + (i % 5 == 0 ? 0.003 : -0.002) + offsetLng,
            ));
          }
        }
        break;
      default:
        path.add(LatLng(center.latitude + offsetLat, center.longitude + offsetLng));
    }

    return path;
  }

  void _startDroneAnimation() {
    _pathTimer?.cancel();
    
    // Generate paths for all 5 drones
    final center = currentLocation ?? defaultCenter;
    dronePath = _generatePath('Spiral', dronePosition, offsetIndex: 0);
    currentPathIndex = 0;

    drone2Path = _generatePath('Spiral', drone2Position, offsetIndex: 1);
    drone2PathIndex = 0;

    drone3Path = _generatePath('Spiral', drone3Position, offsetIndex: 2);
    drone3PathIndex = 0;

    drone4Path = _generatePath('Spiral', drone4Position, offsetIndex: 3);
    drone4PathIndex = 0;

    drone5Path = _generatePath('Spiral', drone5Position, offsetIndex: 4);
    drone5PathIndex = 0;

    _pathTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Animate all 5 drones
      if (currentPathIndex < dronePath.length - 1) {
        setState(() {
          currentPathIndex++;
          dronePosition = dronePath[currentPathIndex];
        });
      } else {
        currentPathIndex = 0;
      }

      if (drone2PathIndex < drone2Path.length - 1) {
        setState(() {
          drone2PathIndex++;
          drone2Position = drone2Path[drone2PathIndex];
        });
      } else {
        drone2PathIndex = 0;
      }

      if (drone3PathIndex < drone3Path.length - 1) {
        setState(() {
          drone3PathIndex++;
          drone3Position = drone3Path[drone3PathIndex];
        });
      } else {
        drone3PathIndex = 0;
      }

      if (drone4PathIndex < drone4Path.length - 1) {
        setState(() {
          drone4PathIndex++;
          drone4Position = drone4Path[drone4PathIndex];
        });
      } else {
        drone4PathIndex = 0;
      }

      if (drone5PathIndex < drone5Path.length - 1) {
        setState(() {
          drone5PathIndex++;
          drone5Position = drone5Path[drone5PathIndex];
        });
      } else {
        drone5PathIndex = 0;
      }
    });
  }

  @override
  void dispose() {
    _droneSubscription?.cancel();
    _zonesSubscription?.cancel();
    _pathTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANT untuk AutomaticKeepAliveClientMixin
    final bool isWide = MediaQuery.of(context).size.width >= 1100;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('LIVE MAP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      isWide
          ? SizedBox(
              height: 600,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: _buildMapArea()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildRightPanel()),
              ]),
            )
          : Column(children: [
              SizedBox(height: 400, child: _buildMapArea()),
              const SizedBox(height: 20),
              SizedBox(height: 400, child: _buildRightPanel()),
            ]),
    ]);
  }

  Widget _buildMapArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation ?? defaultCenter,
              initialZoom: 16.0,
              onTap: incidentMode ? (tapPosition, point) => _handleMapTap(point) : null,
            ),
            children: [
              _tileLayer(),
              if (showTrails) _pathLayer(),
              if (currentLocation != null) _currentLocationMarker(),
              _droneMarkers(),
              if (incidentMarkers.isNotEmpty) _incidentMarkersLayer(),
              if (redZone != null || greenZone != null || lowRiskZone != null || mediumRiskZone != null) _hazardousZonesLayer(),
            ],
          ),
          Positioned(top: 16, right: 16, child: _mapControls()),
          Positioned(bottom: 16, left: 16, child: _zoomButtons()),
          if (incidentMode)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getColorForSeverity(incidentSeverity).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_location, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to add ${incidentSeverity.toUpperCase()} incident',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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

  Widget _tileLayer() {
    return TileLayer(
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      userAgentPackageName: 'com.example.cbrn4',
    );
  }

  Widget _pathLayer() {
    List<Polyline> polylines = [
      // First drone path
      if (dronePath.length > 1)
        Polyline(
          points: dronePath,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
      // Second drone path
      if (drone2Path.length > 1)
        Polyline(
          points: drone2Path,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
      // Third drone path
      if (drone3Path.length > 1)
        Polyline(
          points: drone3Path,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
      // Fourth drone path
      if (drone4Path.length > 1)
        Polyline(
          points: drone4Path,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
      // Fifth drone path
      if (drone5Path.length > 1)
        Polyline(
          points: drone5Path,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
    ];

    return PolylineLayer(polylines: polylines);
  }

  Widget _currentLocationMarker() {
    return MarkerLayer(
      markers: [
        Marker(
          point: currentLocation!,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.my_location, color: Colors.black, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _droneMarkers() {
    return MarkerLayer(
      markers: [
        // First drone
        Marker(
          point: dronePosition,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
        // Second drone
        Marker(
          point: drone2Position,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
        // Third drone
        Marker(
          point: drone3Position,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
        // Fourth drone
        Marker(
          point: drone4Position,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
        // Fifth drone
        Marker(
          point: drone5Position,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
      ],
    );
  }


  Widget _zoomButtons() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101915).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1C2A24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => mapController.move(mapController.camera.center, mapController.camera.zoom + 1),
            icon: const Icon(Icons.add, size: 20),
            padding: const EdgeInsets.all(8),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF1C2A24), foregroundColor: const Color(0xFFE6F4EE)),
          ),
          const SizedBox(height: 1),
          IconButton(
            onPressed: () => mapController.move(mapController.camera.center, mapController.camera.zoom - 1),
            icon: const Icon(Icons.remove, size: 20),
            padding: const EdgeInsets.all(8),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF1C2A24), foregroundColor: const Color(0xFFE6F4EE)),
          ),
        ],
      ),
    );
  }

  Widget _mapControls() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101915).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1C2A24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapToggle(label: 'Pan Mode', active: true, onTap: () {}),
          const SizedBox(height: 6),
          _mapToggle(
            label: 'Layer: ${layerType[0].toUpperCase()}${layerType.substring(1)}',
            active: layerType == 'standard',
            onTap: () => setState(() => layerType = layerType == 'standard' ? 'satellite' : 'standard'),
          ),
          const SizedBox(height: 6),
          _mapToggle(
            label: 'Trails: ${showTrails ? 'ON' : 'OFF'}',
            active: showTrails,
            onTap: () => setState(() => showTrails = !showTrails),
          ),
          const SizedBox(height: 6),
          _mapToggle(
            label: 'Plume: ${plumeOn ? 'ON' : 'OFF'}',
            active: plumeOn,
            onTap: () => setState(() => plumeOn = !plumeOn),
          ),
          const SizedBox(height: 6),
          _mapToggle(
            label: 'Heatmap: ${showHeatmap ? 'ON' : 'OFF'}',
            active: showHeatmap,
            onTap: () => setState(() => showHeatmap = !showHeatmap),
          ),
          const SizedBox(height: 6),
          _mapToggle(
            label: 'Routes: ${showRoutes ? 'ON' : 'OFF'}',
            active: showRoutes,
            onTap: () => setState(() => showRoutes = !showRoutes),
          ),
          const SizedBox(height: 6),
          _mapToggle(
            label: 'Geofences: ${showGeofences ? 'ON' : 'OFF'}',
            active: showGeofences,
            onTap: () => setState(() => showGeofences = !showGeofences),
          ),
        ],
      ),
    );
  }

  Widget _mapToggle({required String label, required bool active, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24),
          foregroundColor: active ? Colors.black : const Color(0xFFE6F4EE),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 0),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildRightPanel() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _grid(
            columns: 2,
            children: [
              _panel(
                title: 'Active Alerts',
                child: Column(
                  children: const [
                    _SeverityRow(label: 'Critical', value: '02', severity: 'critical'),
                    _SeverityRow(label: 'High', value: '04', severity: 'high'),
                    _SeverityRow(label: 'Medium', value: '11', severity: 'medium'),
                    _SeverityRow(label: 'Low', value: '23', severity: 'low'),
                  ]
                ),
              ),
              _panel(
                title: 'Incident Workflow',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      value: incidentSeverity,
                      dropdownColor: const Color(0xFF101915),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'critical', child: Text('Critical')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Low'))
                      ],
                      onChanged: (v) => setState(() => incidentSeverity = v ?? 'critical'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) => setState(() => incidentNote = value),
                      style: const TextStyle(color: Color(0xFFE6F4EE), fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Add incident note (optional)',
                        hintStyle: const TextStyle(color: Color(0xFF7C8B85), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0A0F0D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: const Color(0xFF1C2A24),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF38FF9C),
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => incidentMode = !incidentMode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: incidentMode ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24),
                        foregroundColor: Colors.black,
                      ),
                      child: Text(incidentMode ? 'Add: ON' : 'Add Incident'),
                    ),
                  ],
                ),
              ),
              _panel(
                title: 'Alert Timeline',
                child: Column(
                  children: [
                    DropdownButton<String>(
                      value: timelineFilter,
                      dropdownColor: const Color(0xFF101915),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'critical', child: Text('Critical')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Low'))
                      ],
                      onChanged: (v) => setState(() => timelineFilter = v ?? 'all'),
                    ),
                    const SizedBox(height: 8),
                    ..._filteredAlerts().map((a) => _TimelineRow(alert: a)),
                  ],
                ),
              ),
              _panel(
                title: 'Notification Center',
                child: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => notificationSoundOn = !notificationSoundOn),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)),
                          child: Text('Sound: ${notificationSoundOn ? 'On' : 'Off'}'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _handleTestAlert,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)),
                          child: const Text('Test'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...notifications.take(3).map((n) => _TimelineRow(notification: n)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _panel(
                title: 'Data Export',
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _exportToJSON,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)),
                      child: const Text('JSON'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _exportToCSV,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)),
                      child: const Text('CSV'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<AlertItem> _filteredAlerts() {
    if (timelineFilter == 'all') return alertTimelineData;
    return alertTimelineData.where((a) => a.severity == timelineFilter).toList();
  }

  void _handleTestAlert() {
    final now = DateTime.now();
    setState(() => notifications.insert(0, NotificationItem(id: now.millisecond, message: 'Test alert', time: '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}')));
  }

  Future<void> _exportToJSON() async {
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'alerts': alertTimelineData.map((a) => {
        'id': a.id,
        'severity': a.severity,
        'message': a.message,
        'time': a.time,
      }).toList(),
      'notifications': notifications.map((n) => {
        'id': n.id,
        'message': n.message,
        'time': n.time,
      }).toList(),
      'drones': drones.map((d) => {
        'id': d.id,
        'name': d.name,
        'position': {
          'latitude': d.position.latitude,
          'longitude': d.position.longitude,
        },
        'status': d.status,
        'battery': d.battery,
      }).toList(),
      'hazardousZones': hazardousZones.map((z) => {
        'name': z.name,
        'center': {
          'latitude': z.center.latitude,
          'longitude': z.center.longitude,
        },
        'radiusKm': z.radiusKm,
        'severity': z.severity,
        'substanceType': z.substanceType,
        'detected': z.detected,
      }).toList(),
      'incidents': incidentMarkers.map((i) => {
        'id': i.id,
        'position': {
          'latitude': i.position.latitude,
          'longitude': i.position.longitude,
        },
        'severity': i.severity,
        'note': i.note,
        'timestamp': i.timestamp.toIso8601String(),
      }).toList(),
      'userLocation': currentLocation != null ? {
        'latitude': currentLocation!.latitude,
        'longitude': currentLocation!.longitude,
      } : null,
    };

    final jsonString = jsonEncode(exportData);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await Share.share(
      'CBRN4 Live Map Data Export\n\n$jsonString',
      subject: 'CBRN4_Export_$timestamp.json',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data exported to JSON format'),
        backgroundColor: Color(0xFF38FF9C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    final buffer = StringBuffer();

    // Write CSV header
    buffer.writeln('Type,ID,Severity/Status,Message/Name,Time,Timestamp,Latitude,Longitude,Extra');

    // Write alerts
    for (var alert in alertTimelineData) {
      buffer.writeln('Alert,${alert.id},${alert.severity},"${alert.message}",${alert.time},,,');
    }

    // Write notifications
    for (var notification in notifications) {
      buffer.writeln('Notification,${notification.id},,"${notification.message}",${notification.time},,,');
    }

    // Write drones
    for (var drone in drones) {
      buffer.writeln('Drone,${drone.id},${drone.status},"${drone.name}",,${drone.position.latitude},${drone.position.longitude},Battery: ${drone.battery}%');
    }

    // Write hazardous zones
    for (var zone in hazardousZones) {
      buffer.writeln('HazardousZone,${zone.name.hashCode},${zone.severity},"${zone.name}",,${zone.center.latitude},${zone.center.longitude},Radius: ${zone.radiusKm}km, Substance: ${zone.substanceType}');
    }

    // Write incidents
    for (var incident in incidentMarkers) {
      buffer.writeln('Incident,${incident.id},${incident.severity},"${incident.note}",,${incident.position.latitude},${incident.position.longitude},Timestamp: ${incident.timestamp.toIso8601String()}');
    }

    // Write user location
    if (currentLocation != null) {
      buffer.writeln('UserLocation,0,,"Current Location",,${currentLocation!.latitude},${currentLocation!.longitude},');
    }

    final csvString = buffer.toString();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await Share.share(
      'CBRN4 Live Map Data Export (CSV)\n\n$csvString',
      subject: 'CBRN4_Export_$timestamp.csv',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data exported to CSV format'),
        backgroundColor: Color(0xFF38FF9C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  void _handleMapTap(LatLng position) {
    if (!incidentMode) return;

    // Create new incident
    final now = DateTime.now();
    final incident = IncidentMarker(
      id: now.millisecondsSinceEpoch,
      position: position,
      severity: incidentSeverity,
      note: incidentNote.isEmpty ? 'Incident reported' : incidentNote,
      timestamp: now,
    );

    // Add to incident markers
    setState(() {
      incidentMarkers.add(incident);
    });

    // Add to alert timeline
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final alert = AlertItem(
      id: incident.id,
      severity: incidentSeverity,
      message: incidentNote.isEmpty ? 'New incident reported' : incidentNote,
      time: timeString,
    );
    setState(() {
      alertTimelineData.insert(0, alert);
    });

    // Create hazardous zone based on severity
    final zone = HazardousZone(
      name: 'Incident Zone ${incidentMarkers.length}',
      center: position,
      radiusKm: _getRadiusForSeverity(incidentSeverity),
      severity: incidentSeverity,
      substanceType: _getSubstanceTypeForSeverity(incidentSeverity),
      detected: true,
    );

    setState(() {
      hazardousZones.add(zone);
    });

    // Turn off incident mode after adding
    setState(() {
      incidentMode = false;
      incidentNote = '';
    });

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Incident added at ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
        backgroundColor: _getColorForSeverity(incidentSeverity),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  double _getRadiusForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return 0.5;
      case 'high':
        return 0.4;
      case 'medium':
        return 0.3;
      case 'low':
        return 0.2;
      default:
        return 0.3;
    }
  }

  String _getSubstanceTypeForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return 'hazardous_chemical';
      case 'high':
        return 'dangerous_material';
      case 'medium':
        return 'mild_chemical';
      case 'low':
        return 'suspicious_substance';
      default:
        return 'unknown';
    }
  }

  Color _getColorForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFFF4D4F);
      case 'high':
        return const Color(0xFFFF7A45);
      case 'medium':
        return const Color(0xFFFFB020);
      case 'low':
        return const Color(0xFF2F80ED);
      default:
        return const Color(0xFF38FF9C);
    }
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (c, constr) {
        final w = constr.maxWidth;
        final adj = w < 800 ? 1 : w < 1200 ? (columns > 2 ? 2 : columns) : columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children.map((child) => SizedBox(width: (w - (16 * (adj - 1))) / adj, child: child)).toList(),
        );
      },
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101915),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2A24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ]
      ),
    );
  }

  Widget _hazardousZonesLayer() {
    List<Marker> markers = [];

    // Add red zone (dangerous) - critical
    if (redZone != null) {
      markers.add(
        Marker(
          point: redZone!.center,
          width: 150,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4D4F).withOpacity(redZone!.detected ? 0.6 : 0.2),
              border: Border.all(
                color: const Color(0xFFFF4D4F),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }

    // Add green zone (safe)
    if (greenZone != null) {
      markers.add(
        Marker(
          point: greenZone!.center,
          width: 150,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38FF9C).withOpacity(greenZone!.detected ? 0.6 : 0.2),
              border: Border.all(
                color: const Color(0xFF38FF9C),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }

    // Add low risk zone (yellow) - low risk
    if (lowRiskZone != null) {
      markers.add(
        Marker(
          point: lowRiskZone!.center,
          width: 150,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB020).withOpacity(lowRiskZone!.detected ? 0.6 : 0.2),
              border: Border.all(
                color: const Color(0xFFFFB020),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }

    // Add high risk zone (orange) - high risk
    if (mediumRiskZone != null) {
      markers.add(
        Marker(
          point: mediumRiskZone!.center,
          width: 150,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF7A45).withOpacity(mediumRiskZone!.detected ? 0.6 : 0.2),
              border: Border.all(
                color: const Color(0xFFFF7A45),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (markers.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(markers: markers);
  }

  Widget _incidentMarkersLayer() {
    List<Marker> markers = [];

    for (var incident in incidentMarkers) {
      markers.add(
        Marker(
          point: incident.position,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showIncidentDetails(incident),
            child: Container(
              decoration: BoxDecoration(
                color: _getColorForSeverity(incident.severity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getColorForSeverity(incident.severity).withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.warning,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    if (markers.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(markers: markers);
  }

  void _showIncidentDetails(IncidentMarker incident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101915),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _getColorForSeverity(incident.severity),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getColorForSeverity(incident.severity),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Incident Details',
              style: const TextStyle(
                color: Color(0xFFE6F4EE),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Severity', incident.severity.toUpperCase()),
            const SizedBox(height: 8),
            _buildDetailRow('Note', incident.note),
            const SizedBox(height: 8),
            _buildDetailRow('Time', '${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')}:${incident.timestamp.second.toString().padLeft(2, '0')}'),
            const SizedBox(height: 8),
            _buildDetailRow('Location', '${incident.position.latitude.toStringAsFixed(4)}, ${incident.position.longitude.toStringAsFixed(4)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF38FF9C),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                incidentMarkers.removeWhere((i) => i.id == incident.id);
                alertTimelineData.removeWhere((a) => a.id == incident.id);
                hazardousZones.removeWhere((z) => z.name.contains('Incident Zone'));
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7C8B85),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE6F4EE),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class AlertItem {
  final int id;
  final String severity, message, time;
  AlertItem({required this.id, required this.severity, required this.message, required this.time});
}

class NotificationItem {
  final int id;
  final String message, time;
  NotificationItem({required this.id, required this.message, required this.time});
}

class Drone {
  final int id;
  final String name;
  final LatLng position;
  final String status;
  final int battery;
  Drone({
    required this.id,
    required this.name,
    required this.position,
    required this.status,
    required this.battery,
  });
}

class _SeverityRow extends StatelessWidget {
  final String label, value, severity;
  const _SeverityRow({required this.label, required this.value, required this.severity});

  Color _c() {
    switch (severity) {
      case 'critical': return const Color(0xFFFF4D4F);
      case 'high': return const Color(0xFFFF7A45);
      case 'medium': return const Color(0xFFFFB020);
      default: return const Color(0xFF2F80ED);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _c(), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final AlertItem? alert;
  final NotificationItem? notification;
  const _TimelineRow({this.alert, this.notification});

  Color _sc(String s) {
    switch (s) {
      case 'critical': return const Color(0xFFFF4D4F);
      case 'high': return const Color(0xFFFF7A45);
      case 'medium': return const Color(0xFFFFB020);
      default: return const Color(0xFF2F80ED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = alert?.message ?? notification?.message ?? '';
    final t = alert?.time ?? notification?.time ?? '';
    final clr = alert == null ? const Color(0xFF38FF9C) : _sc(alert!.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: clr, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(txt, style: const TextStyle(fontSize: 11)),
          ),
          Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF7C8B85))),
        ],
      ),
    );
  }
}

class HazardousZone {
  final String name;
  final LatLng center;
  final double radiusKm;
  final String severity;
  final String substanceType;
  bool detected;
  final Set<String> detectedByDrones;

  HazardousZone({
    required this.name,
    required this.center,
    required this.radiusKm,
    required this.severity,
    required this.substanceType,
    this.detected = false,
    Set<String>? detectedByDrones,
  }) : detectedByDrones = detectedByDrones ?? {};
}

class IncidentMarker {
  final int id;
  final LatLng position;
  final String severity;
  final String note;
  final DateTime timestamp;

  IncidentMarker({
    required this.id,
    required this.position,
    required this.severity,
    required this.note,
    required this.timestamp,
  });
}
