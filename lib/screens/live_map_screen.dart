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

// DetectedSubstance class
class DetectedSubstance {
  final String name, type, severity, time;
  final double lat, lng;
  DetectedSubstance({required this.name, required this.type, required this.lat, required this.lng, required this.severity, required this.time});
}

// PathNode class for A* pathfinding
class PathNode {
  final LatLng position;
  final double g; // Cost from start
  final double h; // Heuristic to end
  final PathNode? parent;
  
  PathNode(this.position, this.g, this.h, this.parent);
  
  double get f => g + h;
}

// CBRN Hotspot class
class CBRNHotspot {
  final String name;
  final String type;
  final String severity;
  final LatLng position;
  final double radius;
  final DateTime detectedTime;
  final String detectedBy;
  final double detectedValue;
  final String unit;
  final double threshold;

  CBRNHotspot({
    required this.name,
    required this.type,
    required this.severity,
    required this.position,
    required this.radius,
    required this.detectedTime,
    required this.detectedBy,
    required this.detectedValue,
    required this.unit,
    required this.threshold,
  });
}

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
  bool showGeofences = false;
  bool plumeOn = false;
  String incidentSeverity = 'critical';
  String incidentNote = '';
  bool incidentMode = false;
  String timelineFilter = 'all';
  bool notificationSoundOn = true;
  List<IncidentMarker> incidentMarkers = [];

  // CBRN Detection simulation
  Timer? _cbrnDetectionTimer;
  final List<CBRNHotspot> cbrnHotspots = [];
  final Map<String, List<DetectedSubstance>> detectedSubstancesByType = {
    'Chemical': [],
    'Biological': [],
    'Radiological': [],
    'Nuclear': [],
  };
  
  // Detection radius around drone paths (in degrees)
  // 0.001 degrees ≈ 100 meters at the equator
  double detectionRadius = 0.001;

  // Predefined CBRN substances for simulation
  static final List<Map<String, dynamic>> cbrnSubstances = [
    // Chemical
    {'name': 'Chlorine', 'type': 'Chemical', 'severity': 'high', 'icon': Icons.science, 'color': const Color(0xFFFFB020), 'threshold': 0.5, 'unit': 'ppm', 'maxValue': 10.0},
    {'name': 'Sarin', 'type': 'Chemical', 'severity': 'critical', 'icon': Icons.warning, 'color': const Color(0xFFFF4D4F), 'threshold': 0.01, 'unit': 'ppm', 'maxValue': 1.0},
    {'name': 'Mustard Gas', 'type': 'Chemical', 'severity': 'critical', 'icon': Icons.warning, 'color': const Color(0xFFFF4D4F), 'threshold': 0.1, 'unit': 'ppm', 'maxValue': 2.0},
    {'name': 'VX', 'type': 'Chemical', 'severity': 'critical', 'icon': Icons.warning, 'color': const Color(0xFFFF4D4F), 'threshold': 0.01, 'unit': 'ppm', 'maxValue': 1.0},
    {'name': 'Ammonia', 'type': 'Chemical', 'severity': 'medium', 'icon': Icons.science, 'color': const Color(0xFFFFB020), 'threshold': 25.0, 'unit': 'ppm', 'maxValue': 300.0},
    {'name': 'CO2', 'type': 'Chemical', 'severity': 'medium', 'icon': Icons.cloud, 'color': const Color(0xFFFFB020), 'threshold': 1000.0, 'unit': 'ppm', 'maxValue': 5000.0},
    {'name': 'Sulfur Dioxide', 'type': 'Chemical', 'severity': 'high', 'icon': Icons.science, 'color': const Color(0xFFFFB020), 'threshold': 0.1, 'unit': 'ppm', 'maxValue': 5.0},
    {'name': 'Hydrogen Cyanide', 'type': 'Chemical', 'severity': 'critical', 'icon': Icons.warning, 'color': const Color(0xFFFF4D4F), 'threshold': 0.01, 'unit': 'ppm', 'maxValue': 1.0},
    {'name': 'Phosgene', 'type': 'Chemical', 'severity': 'critical', 'icon': Icons.warning, 'color': const Color(0xFFFF4D4F), 'threshold': 0.01, 'unit': 'ppm', 'maxValue': 1.0},
    // Biological
    {'name': 'Anthrax', 'type': 'Biological', 'severity': 'critical', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 100, 'unit': 'CFU/m³', 'maxValue': 10000},
    {'name': 'Smallpox', 'type': 'Biological', 'severity': 'critical', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 10, 'unit': 'CFU/m³', 'maxValue': 1000},
    {'name': 'Botulinum', 'type': 'Biological', 'severity': 'high', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 50, 'unit': 'CFU/m³', 'maxValue': 5000},
    {'name': 'Ebola', 'type': 'Biological', 'severity': 'critical', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 100, 'unit': 'CFU/m³', 'maxValue': 10000},
    {'name': 'Plague', 'type': 'Biological', 'severity': 'high', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 50, 'unit': 'CFU/m³', 'maxValue': 5000},
    {'name': 'Ricin', 'type': 'Biological', 'severity': 'high', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 100, 'unit': 'CFU/m³', 'maxValue': 10000},
    {'name': 'Tularemia', 'type': 'Biological', 'severity': 'critical', 'icon': Icons.bubble_chart, 'color': const Color(0xFF9C27B0), 'threshold': 10, 'unit': 'CFU/m³', 'maxValue': 1000},
    // Radiological
    {'name': 'Cesium-137', 'type': 'Radiological', 'severity': 'high', 'icon': Icons.radio_button_checked, 'color': const Color(0xFF00D4FF), 'threshold': 0.1, 'unit': 'µSv/h', 'maxValue': 10.0},
    {'name': 'Cobalt-60', 'type': 'Radiological', 'severity': 'high', 'icon': Icons.radio_button_checked, 'color': const Color(0xFF00D4FF), 'threshold': 0.1, 'unit': 'µSv/h', 'maxValue': 10.0},
    {'name': 'Iridium-192', 'type': 'Radiological', 'severity': 'medium', 'icon': Icons.radio_button_checked, 'color': const Color(0xFF00D4FF), 'threshold': 0.5, 'unit': 'µSv/h', 'maxValue': 20.0},
    {'name': 'Strontium-90', 'type': 'Radiological', 'severity': 'high', 'icon': Icons.radio_button_checked, 'color': const Color(0xFF00D4FF), 'threshold': 0.1, 'unit': 'µSv/h', 'maxValue': 10.0},
    {'name': 'Plutonium-239', 'type': 'Radiological', 'severity': 'critical', 'icon': Icons.radio_button_checked, 'color': const Color(0xFF00D4FF), 'threshold': 0.05, 'unit': 'µSv/h', 'maxValue': 5.0},
    {'name': 'Americium-241', 'type': 'Radiological', 'severity': 'high', 'icon': Icons.radio_button_checked, 'color': const Color(0xFF00D4FF), 'threshold': 0.5, 'unit': 'µSv/h', 'maxValue': 20.0},
    // Nuclear
    {'name': 'Uranium-235', 'type': 'Nuclear', 'severity': 'critical', 'icon': Icons.flash_on, 'color': const Color(0xFFFF4D4F), 'threshold': 0.01, 'unit': 'µSv/h', 'maxValue': 2.0},
    {'name': 'Plutonium-239', 'type': 'Nuclear', 'severity': 'critical', 'icon': Icons.flash_on, 'color': const Color(0xFFFF4D4F), 'threshold': 0.01, 'unit': 'µSv/h', 'maxValue': 2.0},
    {'name': 'Tritium', 'type': 'Nuclear', 'severity': 'high', 'icon': Icons.flash_on, 'color': const Color(0xFFFF4D4F), 'threshold': 0.1, 'unit': 'µSv/h', 'maxValue': 5.0},
    {'name': 'Neptunium-237', 'type': 'Nuclear', 'severity': 'high', 'icon': Icons.flash_on, 'color': const Color(0xFFFF4D4F), 'threshold': 0.1, 'unit': 'µSv/h', 'maxValue': 5.0},
    {'name': 'Americium-241', 'type': 'Nuclear', 'severity': 'medium', 'icon': Icons.flash_on, 'color': const Color(0xFFFF4D4F), 'threshold': 0.5, 'unit': 'µSv/h', 'maxValue': 10.0},
  ];

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

  // Drone data
  final List<Drone> drones = [];
  StreamSubscription<Map<String, dynamic>>? _droneSubscription;
  
  StreamSubscription<Map<String, dynamic>>? _zonesSubscription;

  // Evacuation routes
  List<List<LatLng>> evacuationRoutes = [];
  List<LatLng> safeEvacuationPoints = [];
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
    _startCBRNDetectionSimulation();
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

  // CBRN Detection Simulation
  void _startCBRNDetectionSimulation() {
    _cbrnDetectionTimer?.cancel();
    
    // Start simulation timer - detects substances every 5-10 seconds
    _cbrnDetectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Random chance to detect a substance (30% chance each tick)
      if (math.Random().nextDouble() < 0.3) {
        _generateRandomCBRNDetection();
      }
    });
  }

  void _generateRandomCBRNDetection() {
    final center = currentLocation ?? defaultCenter;
    final random = math.Random();
    
    // Select random substance from predefined list
    final substanceData = cbrnSubstances[random.nextInt(cbrnSubstances.length)];
    
    // Get all available drone paths
    final List<List<LatLng>> allPaths = [];
    final List<String> droneNames = [];
    
    if (dronePath.isNotEmpty) {
      allPaths.add(dronePath);
      droneNames.add('Drone Alpha');
    }
    if (drone2Path.isNotEmpty) {
      allPaths.add(drone2Path);
      droneNames.add('Drone Bravo');
    }
    if (drone3Path.isNotEmpty) {
      allPaths.add(drone3Path);
      droneNames.add('Drone Charlie');
    }
    if (drone4Path.isNotEmpty) {
      allPaths.add(drone4Path);
      droneNames.add('Drone Delta');
    }
    if (drone5Path.isNotEmpty) {
      allPaths.add(drone5Path);
      droneNames.add('Drone Echo');
    }
    
    // If no paths available, fallback to center
    LatLng detectionPosition;
    String detectedBy;
    
    if (allPaths.isEmpty) {
      // Fallback: generate random position around the center (within 0.005 degrees ~500m)
      final latOffset = (random.nextDouble() - 0.5) * 0.01;
      final lngOffset = (random.nextDouble() - 0.5) * 0.01;
      detectionPosition = LatLng(
        center.latitude + latOffset,
        center.longitude + lngOffset,
      );
      detectedBy = 'Drone Alpha';
    } else {
      // Select random drone path
      final pathIndex = random.nextInt(allPaths.length);
      final selectedPath = allPaths[pathIndex];
      detectedBy = droneNames[pathIndex];
      
      // Select random point along the path
      final pathPointIndex = random.nextInt(selectedPath.length);
      final pathPoint = selectedPath[pathPointIndex];
      
      // Generate detection position within the configured radius around the path point
      final latOffset = (random.nextDouble() - 0.5) * 2 * detectionRadius;
      final lngOffset = (random.nextDouble() - 0.5) * 2 * detectionRadius;
      
      detectionPosition = LatLng(
        pathPoint.latitude + latOffset,
        pathPoint.longitude + lngOffset,
      );
    }
    
    // Generate random detected value (between 0 and maxValue)
    final maxValue = substanceData['maxValue'] as double;
    final threshold = substanceData['threshold'] as double;
    final detectedValue = random.nextDouble() * maxValue;
    final unit = substanceData['unit'] as String;
    
    // Create detected substance
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    final substance = DetectedSubstance(
      name: substanceData['name'],
      type: substanceData['type'],
      lat: detectionPosition.latitude,
      lng: detectionPosition.longitude,
      severity: substanceData['severity'],
      time: timeStr,
    );
    
    // Check if detected value is above threshold
    final isAboveThreshold = detectedValue >= threshold;
    
    // Create hotspot only if above threshold
    CBRNHotspot? hotspot;
    if (isAboveThreshold) {
      hotspot = CBRNHotspot(
        name: substanceData['name'],
        type: substanceData['type'],
        severity: substanceData['severity'],
        position: detectionPosition,
        radius: _getRadiusForSeverity(substanceData['severity']),
        detectedTime: now,
        detectedBy: detectedBy,
        detectedValue: detectedValue,
        unit: unit,
        threshold: threshold,
      );
    }
    
    setState(() {
      // Always add to detected substances by type (database)
      detectedSubstancesByType[substanceData['type']]!.add(substance);
      
      // Only add to hotspots list if above threshold (limit to 10)
      if (hotspot != null) {
        cbrnHotspots.add(hotspot!);
        if (cbrnHotspots.length > 10) {
          cbrnHotspots.removeAt(0);
        }
      }
      
      // Add to alert timeline
      final statusText = isAboveThreshold ? 'DETECTED' : 'MONITORING';
      alertTimelineData.insert(0, AlertItem(
        id: alertTimelineData.length + 1,
        severity: substanceData['severity'] == 'critical' ? 'critical' : 
                    substanceData['severity'] == 'high' ? 'high' : 'medium',
        message: '$detectedBy detected ${substanceData['type']}: ${substanceData['name']} - ${detectedValue.toStringAsFixed(2)} $unit (Threshold: ${threshold.toStringAsFixed(2)} $unit) [$statusText]',
        time: timeStr,
      ));
      
      // Keep only last 10 alerts
      if (alertTimelineData.length > 10) {
        alertTimelineData.removeLast();
      }
    });
  }

  // Evacuation Route Calculation Functions
  
  /// Check if a point is inside any CBRN hotspot
  bool _isPointInHotspot(LatLng point) {
    for (final hotspot in cbrnHotspots) {
      final distance = _calculateDistance(point, hotspot.position);
      if (distance <= hotspot.radius) {
        return true;
      }
    }
    return false;
  }

  /// Check if a line segment intersects with any CBRN hotspot
  bool _doesLineIntersectHotspot(LatLng start, LatLng end) {
    // Sample points along the line segment
    final numSamples = 20;
    for (int i = 0; i <= numSamples; i++) {
      final t = i / numSamples;
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lng = start.longitude + (end.longitude - start.longitude) * t;
      final point = LatLng(lat, lng);
      
      if (_isPointInHotspot(point)) {
        return true;
      }
    }
    return false;
  }

  /// Calculate distance between two LatLng points in degrees
  double _calculateDistance(LatLng point1, LatLng point2) {
    final latDiff = point1.latitude - point2.latitude;
    final lngDiff = point1.longitude - point2.longitude;
    return math.sqrt(latDiff * latDiff + lngDiff * lngDiff);
  }

  /// Generate safe evacuation points around the user's location
  void _generateSafeEvacuationPoints() {
    if (currentLocation == null) return;
    
    safeEvacuationPoints.clear();
    final center = currentLocation!;
    final searchRadius = 0.02; // ~2km
    final numDirections = 8; // 8 directions (N, NE, E, SE, S, SW, W, NW)
    final stepsPerDirection = 5;
    
    for (int dir = 0; dir < numDirections; dir++) {
      final angle = (dir * 45) * math.pi / 180; // Convert to radians
      
      for (int step = 1; step <= stepsPerDirection; step++) {
        final distance = (searchRadius / stepsPerDirection) * step;
        final lat = center.latitude + distance * math.cos(angle);
        final lng = center.longitude + distance * math.sin(angle);
        final point = LatLng(lat, lng);
        
        // Check if this point is safe (not in any hotspot)
        if (!_isPointInHotspot(point)) {
          // Also check if the path to this point is safe
          if (!_doesLineIntersectHotspot(center, point)) {
            safeEvacuationPoints.add(point);
            break; // Found a safe point in this direction, move to next direction
          }
        }
      }
    }
  }

  /// Calculate evacuation routes using simple straight lines
  void _calculateEvacuationRoutes() {
    if (currentLocation == null || cbrnHotspots.isEmpty) {
      evacuationRoutes.clear();
      return;
    }
    
    evacuationRoutes.clear();
    _generateSafeEvacuationPoints();
    
    if (safeEvacuationPoints.isEmpty) {
      // No safe points found, try to find the least dangerous path
      _calculateLeastDangerousRoutes();
      return;
    }
    
    // Generate up to 4 evacuation routes to different safe points using straight lines
    final numRoutes = math.min(4, safeEvacuationPoints.length);
    
    for (int i = 0; i < numRoutes; i++) {
      final destination = safeEvacuationPoints[i];
      final route = _findSimpleSafePath(currentLocation!, destination);
      
      if (route.isNotEmpty) {
        evacuationRoutes.add(route);
      }
    }
  }

  /// Find a simple safe path from start to end avoiding hotspots (straight lines only)
  List<LatLng> _findSimpleSafePath(LatLng start, LatLng end) {
    // First, try a direct straight line
    if (!_doesLineIntersectHotspot(start, end)) {
      return [start, end];
    }
    
    // Direct path is blocked, try to find a waypoint to go around the hotspot
    return _findWaypointPath(start, end);
  }

  /// Find a path with a single waypoint to avoid hotspots
  List<LatLng> _findWaypointPath(LatLng start, LatLng end) {
    // Try perpendicular waypoints at different distances
    final distances = [0.005, 0.01, 0.015]; // Different offset distances
    final numAttempts = 8; // Number of directions to try
    
    for (final distance in distances) {
      for (int i = 0; i < numAttempts; i++) {
        final angle = (i * 360 / numAttempts) * math.pi / 180;
        
        // Calculate midpoint
        final midLat = (start.latitude + end.latitude) / 2;
        final midLng = (start.longitude + end.longitude) / 2;
        
        // Add perpendicular offset
        final waypoint = LatLng(
          midLat + distance * math.cos(angle),
          midLng + distance * math.sin(angle),
        );
        
        // Check if waypoint is safe
        if (_isPointInHotspot(waypoint)) {
          continue;
        }
        
        // Check if both segments are safe
        if (!_doesLineIntersectHotspot(start, waypoint) && 
            !_doesLineIntersectHotspot(waypoint, end)) {
          return [start, waypoint, end];
        }
      }
    }
    
    // No safe path found, return direct path (will be marked as unsafe)
    return [start, end];
  }

  /// A* pathfinding algorithm to find safe route
  List<LatLng> _aStarPathfinding(LatLng start, LatLng end) {
    // Discretize the space into a grid
    final gridSize = 0.001; // ~100m grid size
    final maxIterations = 1000;
    
    // Define search bounds
    final minLat = math.min(start.latitude, end.latitude) - 0.01;
    final maxLat = math.max(start.latitude, end.latitude) + 0.01;
    final minLng = math.min(start.longitude, end.longitude) - 0.01;
    final maxLng = math.max(start.longitude, end.longitude) + 0.01;
    
    // Priority queue (simplified as sorted list)
    List<PathNode> openSet = [];
    Set<String> closedSet = {};
    
    // Start node
    final startNode = PathNode(start, 0, _calculateDistance(start, end), null);
    openSet.add(startNode);
    
    int iterations = 0;
    
    while (openSet.isNotEmpty && iterations < maxIterations) {
      iterations++;
      
      // Get node with lowest f score
      openSet.sort((a, b) => a.f.compareTo(b.f));
      final current = openSet.removeAt(0);
      
      // Check if we reached the destination
      if (_calculateDistance(current.position, end) < gridSize) {
        // Reconstruct path
        List<LatLng> path = [];
        PathNode? node = current;
        while (node != null) {
          path.insert(0, node.position);
          node = node.parent;
        }
        return path;
      }
      
      // Add to closed set
      final currentKey = '${current.position.latitude.toStringAsFixed(4)},${current.position.longitude.toStringAsFixed(4)}';
      closedSet.add(currentKey);
      
      // Generate neighbors (8 directions)
      final directions = [
        [0, gridSize], [gridSize, 0], [0, -gridSize], [-gridSize, 0], // Cardinal
        [gridSize, gridSize], [gridSize, -gridSize], [-gridSize, gridSize], [-gridSize, -gridSize] // Diagonal
      ];
      
      for (final dir in directions) {
        final newLat = current.position.latitude + dir[0];
        final newLng = current.position.longitude + dir[1];
        final neighborPos = LatLng(newLat, newLng);
        
        // Check bounds
        if (newLat < minLat || newLat > maxLat || newLng < minLng || newLng > maxLng) {
          continue;
        }
        
        // Check if in hotspot
        if (_isPointInHotspot(neighborPos)) {
          continue;
        }
        
        // Check if already in closed set
        final neighborKey = '${newLat.toStringAsFixed(4)},${newLng.toStringAsFixed(4)}';
        if (closedSet.contains(neighborKey)) {
          continue;
        }
        
        // Calculate costs
        final moveCost = _calculateDistance(current.position, neighborPos);
        final gScore = current.g + moveCost;
        final hScore = _calculateDistance(neighborPos, end);
        
        // Check if neighbor is already in open set with lower g score
        final existingNodeIndex = openSet.indexWhere(
          (n) => _calculateDistance(n.position, neighborPos) < 0.0001,
        );
        
        if (existingNodeIndex >= 0 && openSet[existingNodeIndex].g <= gScore) {
          continue;
        }
        
        // Add or update neighbor
        final neighbor = PathNode(neighborPos, gScore, hScore, current);
        if (existingNodeIndex >= 0) {
          openSet.removeAt(existingNodeIndex);
        }
        openSet.add(neighbor);
      }
    }
    
    // No path found, return direct path (will be marked as unsafe)
    return [start, end];
  }

  /// Calculate least dangerous routes when no completely safe path exists
  void _calculateLeastDangerousRoutes() {
    if (currentLocation == null) return;
    
    evacuationRoutes.clear();
    final center = currentLocation!;
    final searchRadius = 0.02;
    final numRoutes = 4;
    
    for (int i = 0; i < numRoutes; i++) {
      final angle = (i * 90) * math.pi / 180; // 4 directions
      final lat = center.latitude + searchRadius * math.cos(angle);
      final lng = center.longitude + searchRadius * math.sin(angle);
      final destination = LatLng(lat, lng);
      
      // Try to find path with minimal hotspot intersection
      final route = _findPathWithMinimalDanger(center, destination);
      if (route.isNotEmpty) {
        evacuationRoutes.add(route);
      }
    }
  }

  /// Find path with minimal danger (fewest hotspot intersections)
  List<LatLng> _findPathWithMinimalDanger(LatLng start, LatLng end) {
    // Try multiple intermediate waypoints
    final numWaypoints = 5;
    List<LatLng> bestPath = [start, end];
    int minDanger = _countDangerousSegments(bestPath);
    
    for (int i = 1; i < numWaypoints; i++) {
      final t = i / numWaypoints;
      
      // Try waypoint perpendicular to direct path
      final perpLat = (end.longitude - start.longitude) * t;
      final perpLng = -(end.latitude - start.latitude) * t;
      final offset = 0.005; // Offset distance
      
      final waypoint1 = LatLng(
        start.latitude + (end.latitude - start.latitude) * t + perpLat * offset,
        start.longitude + (end.longitude - start.longitude) * t + perpLng * offset,
      );
      
      final waypoint2 = LatLng(
        start.latitude + (end.latitude - start.latitude) * t - perpLat * offset,
        start.longitude + (end.longitude - start.longitude) * t - perpLng * offset,
      );
      
      // Try path with waypoint1
      final path1 = [start, waypoint1, end];
      final danger1 = _countDangerousSegments(path1);
      
      if (danger1 < minDanger) {
        minDanger = danger1;
        bestPath = path1;
      }
      
      // Try path with waypoint2
      final path2 = [start, waypoint2, end];
      final danger2 = _countDangerousSegments(path2);
      
      if (danger2 < minDanger) {
        minDanger = danger2;
        bestPath = path2;
      }
    }
    
    return bestPath;
  }

  /// Count how many segments in a path intersect with hotspots
  int _countDangerousSegments(List<LatLng> path) {
    int count = 0;
    for (int i = 0; i < path.length - 1; i++) {
      if (_doesLineIntersectHotspot(path[i], path[i + 1])) {
        count++;
      }
    }
    return count;
  }

  Color _getColorForCBRNType(String type) {
    switch (type) {
      case 'Chemical':
        return const Color(0xFFFFB020); // Orange
      case 'Biological':
        return const Color(0xFF9C27B0); // Purple
      case 'Radiological':
        return const Color(0xFF00D4FF); // Cyan
      case 'Nuclear':
        return const Color(0xFFFF4D4F); // Red
      default:
        return const Color(0xFF7C8B85); // Gray
    }
  }

  IconData _getIconForCBRNType(String type) {
    switch (type) {
      case 'Chemical':
        return Icons.science;
      case 'Biological':
        return Icons.bubble_chart;
      case 'Radiological':
        return Icons.radio_button_checked;
      case 'Nuclear':
        return Icons.flash_on;
      default:
        return Icons.warning;
    }
  }

  @override
  void dispose() {
    _droneSubscription?.cancel();
    _zonesSubscription?.cancel();
    _pathTimer?.cancel();
    _cbrnDetectionTimer?.cancel();
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
              if (cbrnHotspots.isNotEmpty) _cbrnDangerZonesLayer(),
              if (currentLocation != null) _currentLocationMarker(),
              if (cbrnHotspots.isNotEmpty) _cbrnHotspotsLayer(),
              _droneMarkers(),
              if (incidentMarkers.isNotEmpty) _incidentMarkersLayer(),
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

  Widget _evacuationRoutesLayer() {
    List<Polyline> polylines = [];
    
    // Define colors for different evacuation routes
    final routeColors = [
      const Color(0xFF38FF9C), // Green
      const Color(0xFF00D4FF), // Cyan
      const Color(0xFFFFB020), // Orange
      const Color(0xFF9C27B0), // Purple
    ];
    
    for (int i = 0; i < evacuationRoutes.length; i++) {
      final route = evacuationRoutes[i];
      if (route.length > 1) {
        polylines.add(
          Polyline(
            points: route,
            strokeWidth: 5,
            color: routeColors[i % routeColors.length],
          ),
        );
      }
    }
    
    return PolylineLayer(polylines: polylines);
  }

  Widget _cbrnDangerZonesLayer() {
    List<CircleMarker> circles = [];
    
    for (final hotspot in cbrnHotspots) {
      final color = _getColorForCBRNType(hotspot.type);
      
      circles.add(
        CircleMarker(
          point: hotspot.position,
          radius: hotspot.radius * 111000, // Convert degrees to meters (approximate)
          color: color.withValues(alpha: 0.2),
          borderColor: color.withValues(alpha: 0.6),
          borderStrokeWidth: 2,
          useRadiusInMeter: true,
        ),
      );
    }
    
    if (circles.isEmpty) return const SizedBox.shrink();
    return CircleLayer(circles: circles);
  }

  Widget _evacuationPointsLayer() {
    List<Marker> markers = [];
    final pointColors = [
      const Color(0xFF38FF9C), // Green
      const Color(0xFF00D4FF), // Cyan
      const Color(0xFFFFB020), // Orange
      const Color(0xFF9C27B0), // Purple
    ];
    
    for (int i = 0; i < safeEvacuationPoints.length && i < 4; i++) {
      final point = safeEvacuationPoints[i];
      final color = pointColors[i % pointColors.length];
      markers.add(
        Marker(
          point: point,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.exit_to_app,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
      );
    }
    
    if (markers.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(markers: markers);
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
                title: 'Active Substances',
                child: cbrnHotspots.isEmpty
                    ? const Text('No substances detected', style: TextStyle(fontSize: 12, color: Color(0xFF7C8B85)))
                    : Column(
                        children: cbrnHotspots.take(5).map((hotspot) => _SubstanceRow(hotspot: hotspot)).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _panel(
                title: 'Detection Settings',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection Radius: ${(detectionRadius * 100000).toStringAsFixed(0)} meters',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF38FF9C)),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: detectionRadius * 100000,
                      min: 50,
                      max: 500,
                      divisions: 9,
                      label: '${(detectionRadius * 100000).toStringAsFixed(0)}m',
                      onChanged: (value) {
                        setState(() {
                          detectionRadius = value / 100000;
                        });
                      },
                      activeColor: const Color(0xFF38FF9C),
                      inactiveColor: const Color(0xFF1C2A24),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Substances are detected only along drone flight paths',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7C8B85)),
                    ),
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

  Widget _cbrnHotspotsLayer() {
    List<Marker> markers = [];
    
    for (final hotspot in cbrnHotspots) {
      final color = _getColorForCBRNType(hotspot.type);
      final icon = _getIconForCBRNType(hotspot.type);
      
      markers.add(
        Marker(
          point: hotspot.position,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              // Show hotspot details
              _showCBRNHotspotDialog(hotspot);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing effect for critical severity
                if (hotspot.severity == 'critical')
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.3),
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                // Main marker
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                // Severity indicator
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: hotspot.severity == 'critical' 
                          ? const Color(0xFFFF4D4F)
                          : hotspot.severity == 'high'
                              ? const Color(0xFFFFB020)
                              : const Color(0xFF38FF9C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (markers.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(markers: markers);
  }

  void _showCBRNHotspotDialog(CBRNHotspot hotspot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101915),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getColorForCBRNType(hotspot.type),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIconForCBRNType(hotspot.type), color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotspot.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    hotspot.type,
                    style: TextStyle(color: _getColorForCBRNType(hotspot.type), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCBRNDetailRow('Severity', hotspot.severity.toUpperCase(), _getColorForSeverity(hotspot.severity)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Detected By', hotspot.detectedBy, const Color(0xFF00D4FF)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Detection Time', _formatDateTime(hotspot.detectedTime), const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Detected Value', '${hotspot.detectedValue.toStringAsFixed(2)} ${hotspot.unit}', _getColorForCBRNType(hotspot.type)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Threshold', '${hotspot.threshold.toStringAsFixed(2)} ${hotspot.unit}', const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Status', hotspot.detectedValue >= hotspot.threshold ? 'ABOVE THRESHOLD' : 'BELOW THRESHOLD', hotspot.detectedValue >= hotspot.threshold ? const Color(0xFFFF4D4F) : const Color(0xFF38FF9C)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Radius', '${(hotspot.radius * 100000).toInt()} m', const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildCBRNDetailRow('Position', '${hotspot.position.latitude.toStringAsFixed(6)}, ${hotspot.position.longitude.toStringAsFixed(6)}', const Color(0xFF7C8B85)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Focus on hotspot
              mapController.move(hotspot.position, 18.0);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38FF9C)),
            child: const Text('Focus', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildCBRNDetailRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF7C8B85), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
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

class _SubstanceRow extends StatelessWidget {
  final CBRNHotspot hotspot;
  const _SubstanceRow({required this.hotspot});

  Color _getColorForCBRNType(String type) {
    switch (type) {
      case 'Chemical':
        return const Color(0xFFFFB020); // Orange
      case 'Biological':
        return const Color(0xFF9C27B0); // Purple
      case 'Radiological':
        return const Color(0xFF00D4FF); // Cyan
      case 'Nuclear':
        return const Color(0xFFFF4D4F); // Red
      default:
        return const Color(0xFF7C8B85); // Gray
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

  @override
  Widget build(BuildContext context) {
    final typeColor = _getColorForCBRNType(hotspot.type);
    final severityColor = _getColorForSeverity(hotspot.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: typeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotspot.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE6F4EE),
                  ),
                ),
                Text(
                  '${hotspot.type} · ${(hotspot.radius * 111000).toInt()}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: typeColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: severityColor, width: 1),
            ),
            child: Text(
              hotspot.severity.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: severityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
