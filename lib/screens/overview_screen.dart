// lib/screens/overview_screen.dart

import '../services/firebase_service.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// DetectedSubstance class
class DetectedSubstance {
  final String name, type, severity, time;
  final double lat, lng;
  DetectedSubstance({required this.name, required this.type, required this.lat, required this.lng, required this.severity, required this.time});
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

// Evacuation route class
class EvacuationRoute {
  final String id;
  final String substanceName;
  final String substanceType;
  final LatLng hotspotPosition;
  final LatLng evacuationPoint;
  String status; // 'Planning', 'In Progress', 'Completed'
  final DateTime createdAt;
  DateTime? completedAt;
  final List<LatLng> routePath;

  EvacuationRoute({
    required this.id,
    required this.substanceName,
    required this.substanceType,
    required this.hotspotPosition,
    required this.evacuationPoint,
    required this.status,
    required this.createdAt,
    this.completedAt,
    List<LatLng>? routePath,
  }) : routePath = routePath ?? [] {
      status = 'Planning';
    }
}

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController mapController = MapController();
  final LatLng defaultCenter = const LatLng(51.505, -0.09);
  LatLng? currentLocation;

  // Click state for drone names
  String? selectedDroneName;

  String missionStatus = 'STANDBY';
  int missionSeconds = 0;
  bool isMissionRunning = false;
  bool isMissionPaused = false;
  String selectedOpMode = 'Multi-Drone Surveillance';
  String selectedMovement = 'Manual Control';

  // Drone path variables
  List<LatLng> dronePath = [];
  int currentPathIndex = 0;
  Timer? _pathTimer;
  LatLng dronePosition = const LatLng(51.505, -0.09);

  // Second drone path variables
  List<LatLng> drone2Path = [];
  int drone2PathIndex = 0;
  LatLng drone2Position = const LatLng(51.505, -0.09);

  // Additional drones for swarm mode
  List<LatLng> drone3Path = [];
  int drone3PathIndex = 0;
  LatLng drone3Position = const LatLng(51.505, -0.09);

  List<LatLng> drone4Path = [];
  int drone4PathIndex = 0;
  LatLng drone4Position = const LatLng(51.505, -0.09);

  List<LatLng> drone5Path = [];
  int drone5PathIndex = 0;
  LatLng drone5Position = const LatLng(51.505, -0.09);
  final List<DetectedSubstance> detectedSubstances = [];

  // Battery levels for each drone
  int drone1Battery = 98;
  int drone2Battery = 85;
  int drone3Battery = 92;
  int drone4Battery = 88;
  int drone5Battery = 95;

  // Altitude and speed for each drone
  int drone1Altitude = 320;
  int drone2Altitude = 0;
  int drone3Altitude = 280;
  int drone4Altitude = 300;
  int drone5Altitude = 340;

  int drone1Speed = 41;
  int drone2Speed = 12;
  int drone3Speed = 38;
  int drone4Speed = 40;
  int drone5Speed = 42;

  // System Health variables
  double miniBtsHealth = 0.85;
  double reconLinkHealth = 0.92;
  double aiSystemsHealth = 0.78;
  double encryptionHealth = 1.0;
  double uavSwarmHealth = 0.95;
  double ugvFleetHealth = 0.88;

  // Area Status variables
  int highRiskCount = 2;
  int mediumRiskCount = 2;
  int safeZoneCount = 8;

  // Recent activity log
  final List<ActivityLog> activityLog = [];

  // CBRN Detection simulation
  Timer? _cbrnDetectionTimer;
  final List<CBRNHotspot> cbrnHotspots = [];
  final Map<String, List<DetectedSubstance>> detectedSubstancesByType = {
    'Chemical': [],
    'Biological': [],
    'Radiological': [],
    'Nuclear': [],
  };

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

  // Evacuation simulation
  final List<EvacuationRoute> evacuationRoutes = [];
  Timer? _evacuationTimer;
  bool isEvacuationPlanning = false;
  List<LatLng> safeEvacuationPath = [];
  LatLng? selectedEvacuationPoint;

  Timer? _missionTimer;

  void _startMission() {
    final center = currentLocation ?? defaultCenter;
    setState(() {
      isMissionRunning = true;
      isMissionPaused = false;
      missionStatus = 'ACTIVE';
      missionSeconds = 0;

      // Clear previous detections when starting new mission
      cbrnHotspots.clear();
      detectedSubstancesByType['Chemical']!.clear();
      detectedSubstancesByType['Biological']!.clear();
      detectedSubstancesByType['Radiological']!.clear();
      detectedSubstancesByType['Nuclear']!.clear();

      // Generate paths based on operation mode
      if (selectedOpMode == 'Advance UAV Swarm Operation') {
        // Swarm mode: 5 drones
        dronePath = _generatePath(selectedMovement, dronePosition, offsetIndex: 0);
        currentPathIndex = 0;

        drone2Path = _generatePath(selectedMovement, drone2Position, offsetIndex: 1);
        drone2PathIndex = 0;

        drone3Path = _generatePath(selectedMovement, drone3Position, offsetIndex: 2);
        drone3PathIndex = 0;

        drone4Path = _generatePath(selectedMovement, drone4Position, offsetIndex: 3);
        drone4PathIndex = 0;

        drone5Path = _generatePath(selectedMovement, drone5Position, offsetIndex: 4);
        drone5PathIndex = 0;

        // Initialize Firebase with initial drone positions
        FirebaseService().updateDronePosition(
          droneId: 1,
          name: 'UAV-ALPHA-1',
          lat: dronePosition.latitude,
          lng: dronePosition.longitude,
          battery: drone1Battery,
          status: 'Active',
        );
        FirebaseService().updateDronePosition(
          droneId: 2,
          name: 'UGV-DELTA-2',
          lat: drone2Position.latitude,
          lng: drone2Position.longitude,
          battery: drone2Battery,
          status: 'Active',
        );
        FirebaseService().updateDronePosition(
          droneId: 3,
          name: 'UAV-CHARLIE-1',
          lat: drone3Position.latitude,
          lng: drone3Position.longitude,
          battery: drone3Battery,
          status: 'Active',
        );
        FirebaseService().updateDronePosition(
          droneId: 4,
          name: 'UAV-DELTA-1',
          lat: drone4Position.latitude,
          lng: drone4Position.longitude,
          battery: drone4Battery,
          status: 'Active',
        );
        FirebaseService().updateDronePosition(
          droneId: 5,
          name: 'UAV-ECHO-1',
          lat: drone5Position.latitude,
          lng: drone5Position.longitude,
          battery: drone5Battery,
          status: 'Active',
        );
      } else if (selectedOpMode == 'Multi-Drone Surveillance' || selectedOpMode == 'Advanced Mixed Operations') {
        // 2 drones mode
        dronePath = _generatePath(selectedMovement, dronePosition, offsetIndex: 0);
        currentPathIndex = 0;

        drone2Path = _generatePath(selectedMovement, drone2Position, offsetIndex: 1);
        drone2PathIndex = 0;

        // Initialize Firebase with initial drone positions
        FirebaseService().updateDronePosition(
          droneId: 1,
          name: 'UAV-ALPHA-1',
          lat: dronePosition.latitude,
          lng: dronePosition.longitude,
          battery: drone1Battery,
          status: 'Active',
        );
        FirebaseService().updateDronePosition(
          droneId: 2,
          name: 'UGV-DELTA-2',
          lat: drone2Position.latitude,
          lng: drone2Position.longitude,
          battery: drone2Battery,
          status: 'Active',
        );
      } else {
        // Manual mode: only first drone
        dronePath = _generatePath(selectedMovement, dronePosition, offsetIndex: 0);
        currentPathIndex = 0;

        // Initialize Firebase with initial drone position
        FirebaseService().updateDronePosition(
          droneId: 1,
          name: 'UAV-ALPHA-1',
          lat: dronePosition.latitude,
          lng: dronePosition.longitude,
          battery: drone1Battery,
          status: 'Active',
        );
      }
    });
    _startTimer();
    _startPathAnimation();
    _startCBRNDetectionSimulation();
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
      case 'Zigzag':
        // Zigzag pattern - alternating diagonal
        if (offsetIndex % 2 == 1) {
          // Odd index drones - reverse zigzag
          for (int i = 0; i < 10; i++) {
            double lat = center.latitude + (i * latStep * 0.5) + offsetLat;
            double lng = center.longitude + (i % 2 == 0 ? 3 * lngStep : 0) + offsetLng;
            path.add(LatLng(lat, lng));
          }
        } else {
          // Even index drones - normal zigzag
          for (int i = 0; i < 10; i++) {
            double lat = center.latitude + (i * latStep * 0.5) + offsetLat;
            double lng = center.longitude + (i % 2 == 0 ? 0 : 3 * lngStep) + offsetLng;
            path.add(LatLng(lat, lng));
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
      case 'Manual Control':
        // Manual - just stay at center
        path.add(LatLng(center.latitude + offsetLat, center.longitude + offsetLng));
        break;
      default:
        path.add(LatLng(center.latitude + offsetLat, center.longitude + offsetLng));
    }

    return path;
  }

  void _startPathAnimation() {
    _pathTimer?.cancel();
    if (selectedMovement == 'Manual Control') return;

    _pathTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!isMissionRunning || isMissionPaused) return;

      // Animate drones based on operation mode
      if (selectedOpMode == 'Advance UAV Swarm Operation') {
        // Animate all 5 drones
        if (currentPathIndex < dronePath.length - 1) {
          setState(() {
            currentPathIndex++;
            dronePosition = dronePath[currentPathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 1,
            name: 'UAV-ALPHA-1',
            lat: dronePosition.latitude,
            lng: dronePosition.longitude,
            battery: 98,
            status: 'Active',
          );
        } else {
          currentPathIndex = 0;
        }

        if (drone2PathIndex < drone2Path.length - 1) {
          setState(() {
            drone2PathIndex++;
            drone2Position = drone2Path[drone2PathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 2,
            name: 'UGV-DELTA-2',
            lat: drone2Position.latitude,
            lng: drone2Position.longitude,
            battery: 85,
            status: 'Active',
          );
        } else {
          drone2PathIndex = 0;
        }

        if (drone3PathIndex < drone3Path.length - 1) {
          setState(() {
            drone3PathIndex++;
            drone3Position = drone3Path[drone3PathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 3,
            name: 'UAV-CHARLIE-1',
            lat: drone3Position.latitude,
            lng: drone3Position.longitude,
            battery: 92,
            status: 'Active',
          );
        } else {
          drone3PathIndex = 0;
        }

        if (drone4PathIndex < drone4Path.length - 1) {
          setState(() {
            drone4PathIndex++;
            drone4Position = drone4Path[drone4PathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 4,
            name: 'UAV-DELTA-1',
            lat: drone4Position.latitude,
            lng: drone4Position.longitude,
            battery: 88,
            status: 'Active',
          );
        } else {
          drone4PathIndex = 0;
        }

        if (drone5PathIndex < drone5Path.length - 1) {
          setState(() {
            drone5PathIndex++;
            drone5Position = drone5Path[drone5PathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 5,
            name: 'UAV-ECHO-1',
            lat: drone5Position.latitude,
            lng: drone5Position.longitude,
            battery: 95,
            status: 'Active',
          );
        } else {
          drone5PathIndex = 0;
        }
      } else if (selectedOpMode == 'Multi-Drone Surveillance' || selectedOpMode == 'Advanced Mixed Operations') {
        // Animate 2 drones
        if (currentPathIndex < dronePath.length - 1) {
          setState(() {
            currentPathIndex++;
            dronePosition = dronePath[currentPathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 1,
            name: 'UAV-ALPHA-1',
            lat: dronePosition.latitude,
            lng: dronePosition.longitude,
            battery: 98,
            status: 'Active',
          );
        } else {
          currentPathIndex = 0;
        }

        if (drone2PathIndex < drone2Path.length - 1) {
          setState(() {
            drone2PathIndex++;
            drone2Position = drone2Path[drone2PathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 2,
            name: 'UGV-DELTA-2',
            lat: drone2Position.latitude,
            lng: drone2Position.longitude,
            battery: 85,
            status: 'Active',
          );
        } else {
          drone2PathIndex = 0;
        }
      } else {
        // Manual mode - only first drone
        if (currentPathIndex < dronePath.length - 1) {
          setState(() {
            currentPathIndex++;
            dronePosition = dronePath[currentPathIndex];
          });
          FirebaseService().updateDronePosition(
            droneId: 1,
            name: 'UAV-ALPHA-1',
            lat: dronePosition.latitude,
            lng: dronePosition.longitude,
            battery: 98,
            status: 'Active',
          );
        } else {
          currentPathIndex = 0;
        }
      }

      // Center map on first drone
      mapController.move(dronePosition, 16.0);
    });
  }

  // CBRN Detection Simulation
  void _startCBRNDetectionSimulation() {
    _cbrnDetectionTimer?.cancel();
    
    // Start simulation timer - detects substances every 5-10 seconds
    _cbrnDetectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isMissionRunning || isMissionPaused) return;
      
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
    
    // Generate random position around the center (within 0.005 degrees ~500m)
    final latOffset = (random.nextDouble() - 0.5) * 0.01;
    final lngOffset = (random.nextDouble() - 0.5) * 0.01;
    final detectionPosition = LatLng(
      center.latitude + latOffset,
      center.longitude + lngOffset,
    );
    
    // Select random drone that detected it
    final droneNames = ['UAV-ALPHA-1', 'UGV-DELTA-2', 'UAV-CHARLIE-1', 'UAV-DELTA-1', 'UAV-ECHO-1'];
    final detectedBy = droneNames[random.nextInt(droneNames.length)];
    
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
      
      // Add to activity log
      final logType = substanceData['severity'] == 'critical' ? 'critical' :
                      substanceData['severity'] == 'high' ? 'warning' : 'info';
      final statusText = isAboveThreshold ? 'DETECTED' : 'MONITORING';
      activityLog.insert(0, ActivityLog(
        message: '$detectedBy detected ${substanceData['type']}: ${substanceData['name']} - ${detectedValue.toStringAsFixed(2)} $unit (Threshold: ${threshold.toStringAsFixed(2)} $unit) [$statusText]',
        type: logType,
        time: timeStr,
      ));
      
      // Keep only last 20 activity logs
      if (activityLog.length > 20) {
        activityLog.removeLast();
      }
    });
  }
  
  // Generate safe evacuation route based on ALL hotspots and user location
  void _generateSafeEvacuationRoute(CBRNHotspot hotspot) {
    final userPos = currentLocation ?? defaultCenter;
    
    // Find a truly safe evacuation point that's not in ANY danger zone
    LatLng safeEvacuationPoint = _findSafeEvacuationPoint(userPos);
    
    // Generate path that avoids ALL hotspots
    List<LatLng> path = _calculateSafePath(userPos, safeEvacuationPoint, hotspot.position, hotspot.radius);
    
    // Calculate actual distance to safe point
    double distance = _calculateDistance(userPos, safeEvacuationPoint) * 111000; // Convert to meters
    
    setState(() {
      selectedEvacuationPoint = safeEvacuationPoint;
      safeEvacuationPath = path;
      isEvacuationPlanning = true;
      
      // Create evacuation route
      final routeId = 'EVAC-${DateTime.now().millisecondsSinceEpoch}';
      final route = EvacuationRoute(
        id: routeId,
        substanceName: hotspot.name,
        substanceType: hotspot.type,
        hotspotPosition: hotspot.position,
        evacuationPoint: safeEvacuationPoint,
        status: 'Planning',
        createdAt: DateTime.now(),
        routePath: path,
      );
      
      evacuationRoutes.add(route);
      
      // Add to activity log
      final timeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
      activityLog.insert(0, ActivityLog(
        message: 'SAFE EVACUATION ROUTE GENERATED for ${hotspot.name} (${hotspot.type}) - Distance: ${distance.toInt()}m',
        type: 'warning',
        time: timeStr,
      ));
    });
    
    // Center map on evacuation route
    mapController.move(userPos, 15.0);
  }
  
  // Find a truly safe evacuation point that's not in ANY danger zone
  LatLng _findSafeEvacuationPoint(LatLng userPos) {
    // Try multiple directions and distances to find a safe point
    List<double> distances = [0.005, 0.008, 0.010, 0.015, 0.020]; // Different distances to try
    List<double> angles = [];
    
    // Generate angles in 8 directions (45-degree increments)
    for (int i = 0; i < 8; i++) {
      angles.add(i * math.pi / 4);
    }
    
    // Try each combination of distance and angle
    for (final distance in distances) {
      for (final angle in angles) {
        LatLng candidatePoint = LatLng(
          userPos.latitude + math.sin(angle) * distance,
          userPos.longitude + math.cos(angle) * distance,
        );
        
        // Check if this point is safe from ALL hotspots
        if (_isPointSafeFromAllHotspots(candidatePoint)) {
          return candidatePoint;
        }
      }
    }
    
    // If no completely safe point found, return the safest possible point
    return _findSafestPossiblePoint(userPos);
  }
  
  // Find the safest possible point if no completely safe point exists
  LatLng _findSafestPossiblePoint(LatLng userPos) {
    LatLng safestPoint = userPos;
    double lowestDangerScore = double.infinity;
    
    // Try multiple directions and distances
    List<double> distances = [0.005, 0.008, 0.010, 0.015, 0.020];
    List<double> angles = [];
    
    for (int i = 0; i < 8; i++) {
      angles.add(i * math.pi / 4);
    }
    
    for (final distance in distances) {
      for (final angle in angles) {
        LatLng candidatePoint = LatLng(
          userPos.latitude + math.sin(angle) * distance,
          userPos.longitude + math.cos(angle) * distance,
        );
        
        // Calculate danger score for this point
        double dangerScore = _calculateDangerScoreForPoint(candidatePoint);
        
        // Keep the point with the lowest danger score
        if (dangerScore < lowestDangerScore) {
          lowestDangerScore = dangerScore;
          safestPoint = candidatePoint;
        }
      }
    }
    
    return safestPoint;
  }
  
  // Check if a point is safe from ALL hotspots
  bool _isPointSafeFromAllHotspots(LatLng point) {
    for (final hotspot in cbrnHotspots) {
      double distance = _calculateDistance(point, hotspot.position);
      double safeRadius = hotspot.radius * 4.0; // 4x radius for safety
      
      // Increase safety buffer for critical/high severity
      if (hotspot.severity == 'critical') {
        safeRadius = hotspot.radius * 6.0;
      } else if (hotspot.severity == 'high') {
        safeRadius = hotspot.radius * 5.0;
      }
      
      if (distance < safeRadius) {
        return false; // Point is in danger zone
      }
    }
    return true; // Point is safe from all hotspots
  }
  
  // Calculate danger score for a point (lower is safer)
  double _calculateDangerScoreForPoint(LatLng point) {
    double score = 0;
    for (final hotspot in cbrnHotspots) {
      double distance = _calculateDistance(point, hotspot.position);
      double safeRadius = hotspot.radius * 4.0;
      
      if (hotspot.severity == 'critical') {
        safeRadius = hotspot.radius * 6.0;
      } else if (hotspot.severity == 'high') {
        safeRadius = hotspot.radius * 5.0;
      }
      
      // Higher score for points closer to danger
      if (distance < safeRadius) {
        score += (safeRadius - distance) / safeRadius;
      }
      
      // Additional penalty for critical hotspots
      if (hotspot.severity == 'critical') {
        score *= 2.0;
      }
    }
    return score;
  }
  
  // Calculate safe path avoiding ALL hotspots comprehensively
  List<LatLng> _calculateSafePath(LatLng start, LatLng end, LatLng dangerPoint, double dangerRadius) {
    List<LatLng> path = [];
    
    // If no hotspots, return direct path
    if (cbrnHotspots.isEmpty) {
      int numPoints = 20;
      for (int i = 0; i <= numPoints; i++) {
        double t = i / numPoints;
        double lat = start.latitude + (end.latitude - start.latitude) * t;
        double lng = start.longitude + (end.longitude - start.longitude) * t;
        path.add(LatLng(lat, lng));
      }
      return path;
    }
    
    // Calculate safety buffer based on all hotspots
    double maxSafetyBuffer = 0;
    for (final hotspot in cbrnHotspots) {
      double safetyBuffer = hotspot.radius * 4.0; // 4x radius for comprehensive safety
      if (hotspot.severity == 'critical') {
        safetyBuffer = hotspot.radius * 6.0; // 6x for critical
      } else if (hotspot.severity == 'high') {
        safetyBuffer = hotspot.radius * 5.0; // 5x for high
      }
      maxSafetyBuffer = math.max(maxSafetyBuffer, safetyBuffer);
    }
    
    // Use a multi-pass approach for comprehensive avoidance
    // Pass 1: Generate initial path with high resolution
    List<LatLng> initialPath = _generateInitialPath(start, end, 50);
    
    // Pass 2: Refine path to avoid all danger zones
    List<LatLng> refinedPath = _refinePathToAvoidDanger(initialPath, maxSafetyBuffer);
    
    // Pass 3: Smooth the path and add intermediate waypoints
    path = _smoothPath(refinedPath);
    
    return path;
  }
  
  // Generate initial path with high resolution
  List<LatLng> _generateInitialPath(LatLng start, LatLng end, int numPoints) {
    List<LatLng> path = [];
    for (int i = 0; i <= numPoints; i++) {
      double t = i / numPoints;
      double lat = start.latitude + (end.latitude - start.latitude) * t;
      double lng = start.longitude + (end.longitude - start.longitude) * t;
      path.add(LatLng(lat, lng));
    }
    return path;
  }
  
  // Refine path to avoid ALL danger zones
  List<LatLng> _refinePathToAvoidDanger(List<LatLng> initialPath, double safetyBuffer) {
    List<LatLng> refinedPath = [];
    
    for (int i = 0; i < initialPath.length; i++) {
      LatLng point = initialPath[i];
      
      // Check if point is in ANY danger zone
      bool inDangerZone = _isPointInDangerZone(point, safetyBuffer);
      
      if (inDangerZone) {
        // Find safe waypoint(s) around the danger zone
        List<LatLng> safeWaypoints = _findSafeWaypoints(point, initialPath, i, safetyBuffer);
        
        // Add safe waypoints to path
        for (final waypoint in safeWaypoints) {
          if (!_isPointInDangerZone(waypoint, safetyBuffer)) {
            refinedPath.add(waypoint);
          }
        }
      } else {
        refinedPath.add(point);
      }
    }
    
    return refinedPath;
  }
  
  // Check if point is in ANY danger zone
  bool _isPointInDangerZone(LatLng point, double safetyBuffer) {
    for (final hotspot in cbrnHotspots) {
      double distanceToDanger = _calculateDistance(point, hotspot.position);
      double safeRadius = safetyBuffer;
      
      // Use individual hotspot safety buffer if larger
      double individualBuffer = hotspot.radius * 4.0;
      if (hotspot.severity == 'critical') {
        individualBuffer = hotspot.radius * 6.0;
      } else if (hotspot.severity == 'high') {
        individualBuffer = hotspot.radius * 5.0;
      }
      safeRadius = math.max(safeRadius, individualBuffer);
      
      if (distanceToDanger < safeRadius) {
        return true;
      }
    }
    return false;
  }
  
  // Find safe waypoints around danger zones
  List<LatLng> _findSafeWaypoints(LatLng dangerPoint, List<LatLng> path, int currentIndex, double safetyBuffer) {
    List<LatLng> waypoints = [];
    
    // Get previous and next points for direction
    LatLng prevPoint = currentIndex > 0 ? path[currentIndex - 1] : path[0];
    LatLng nextPoint = currentIndex < path.length - 1 ? path[currentIndex + 1] : path[path.length - 1];
    
    // Calculate direction vectors
    double dirLat = nextPoint.latitude - prevPoint.latitude;
    double dirLng = nextPoint.longitude - prevPoint.longitude;
    double pathAngle = math.atan2(dirLat, dirLng);
    
    // Calculate perpendicular angles for going around
    double perpAngle1 = pathAngle + math.pi / 2;
    double perpAngle2 = pathAngle - math.pi / 2;
    
    // Try multiple offset distances
    List<double> offsetDistances = [safetyBuffer * 1.5, safetyBuffer * 2.0, safetyBuffer * 3.0];
    
    for (final offsetDist in offsetDistances) {
      // Try both perpendicular directions
      LatLng waypoint1 = LatLng(
        dangerPoint.latitude + math.sin(perpAngle1) * offsetDist,
        dangerPoint.longitude + math.cos(perpAngle1) * offsetDist,
      );
      
      LatLng waypoint2 = LatLng(
        dangerPoint.latitude + math.sin(perpAngle2) * offsetDist,
        dangerPoint.longitude + math.cos(perpAngle2) * offsetDist,
      );
      
      // Check which waypoint is safer
      double dangerScore1 = _calculateDangerScore(waypoint1, safetyBuffer);
      double dangerScore2 = _calculateDangerScore(waypoint2, safetyBuffer);
      
      // Add the safer waypoint
      if (dangerScore1 < dangerScore2) {
        waypoints.add(waypoint1);
      } else {
        waypoints.add(waypoint2);
      }
    }
    
    // Also try diagonal directions for more options
    double diagAngle1 = pathAngle + math.pi / 4;
    double diagAngle2 = pathAngle - math.pi / 4;
    
    for (final offsetDist in [safetyBuffer * 2.0]) {
      LatLng waypoint3 = LatLng(
        dangerPoint.latitude + math.sin(diagAngle1) * offsetDist,
        dangerPoint.longitude + math.cos(diagAngle1) * offsetDist,
      );
      
      LatLng waypoint4 = LatLng(
        dangerPoint.latitude + math.sin(diagAngle2) * offsetDist,
        dangerPoint.longitude + math.cos(diagAngle2) * offsetDist,
      );
      
      waypoints.add(waypoint3);
      waypoints.add(waypoint4);
    }
    
    return waypoints;
  }
  
  // Calculate danger score for a point (lower is safer)
  double _calculateDangerScore(LatLng point, double safetyBuffer) {
    double score = 0;
    for (final hotspot in cbrnHotspots) {
      double distance = _calculateDistance(point, hotspot.position);
      double safeRadius = safetyBuffer;
      
      double individualBuffer = hotspot.radius * 4.0;
      if (hotspot.severity == 'critical') {
        individualBuffer = hotspot.radius * 6.0;
      } else if (hotspot.severity == 'high') {
        individualBuffer = hotspot.radius * 5.0;
      }
      safeRadius = math.max(safeRadius, individualBuffer);
      
      // Higher score for points closer to danger
      if (distance < safeRadius) {
        score += (safeRadius - distance) / safeRadius;
      }
    }
    return score;
  }
  
  // Smooth the path to remove jagged edges
  List<LatLng> _smoothPath(List<LatLng> path) {
    if (path.length <= 2) return path;
    
    List<LatLng> smoothedPath = [];
    
    // Add first point
    smoothedPath.add(path[0]);
    
    // Use moving average for smoothing
    for (int i = 1; i < path.length - 1; i++) {
      LatLng prev = path[i - 1];
      LatLng current = path[i];
      LatLng next = path[i + 1];
      
      // Calculate average of three points
      double avgLat = (prev.latitude + current.latitude + next.latitude) / 3;
      double avgLng = (prev.longitude + current.longitude + next.longitude) / 3;
      
      smoothedPath.add(LatLng(avgLat, avgLng));
    }
    
    // Add last point
    smoothedPath.add(path[path.length - 1]);
    
    return smoothedPath;
  }
  
  // Calculate distance between two points in degrees (approximate)
  double _calculateDistance(LatLng point1, LatLng point2) {
    double latDiff = point1.latitude - point2.latitude;
    double lngDiff = point1.longitude - point2.longitude;
    return math.sqrt(latDiff * latDiff + lngDiff * lngDiff);
  }
  
  // Start evacuation
  void _startEvacuation(EvacuationRoute route) {
    setState(() {
      route.status = 'In Progress';
    });
    
    // Add to activity log
    final timeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
    activityLog.insert(0, ActivityLog(
      message: 'EVACUATION IN PROGRESS for ${route.substanceName} - Route: ${route.id}',
      type: 'critical',
      time: timeStr,
    ));
    
    // Simulate evacuation completion after 30 seconds
    Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          route.status = 'Completed';
          route.completedAt = DateTime.now();
        });
        
        final completeTimeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
        activityLog.insert(0, ActivityLog(
          message: 'EVACUATION COMPLETED for ${route.substanceName} - Route: ${route.id}',
          type: 'success',
          time: completeTimeStr,
        ));
      }
    });
  }
  
  // Cancel evacuation
  void _cancelEvacuation(EvacuationRoute route) {
    setState(() {
      evacuationRoutes.remove(route);
      if (evacuationRoutes.isEmpty) {
        isEvacuationPlanning = false;
        safeEvacuationPath = [];
        selectedEvacuationPoint = null;
      }
    });
    
    // Add to activity log
    final timeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
    activityLog.insert(0, ActivityLog(
      message: 'EVACUATION CANCELLED for ${route.substanceName} - Route: ${route.id}',
      type: 'info',
      time: timeStr,
    ));
  }

  double _getRadiusForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return 0.003; // ~300m
      case 'high':
        return 0.002; // ~200m
      case 'medium':
        return 0.001; // ~100m
      default:
        return 0.001;
    }
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



  void _stopMission() {
    final center = currentLocation ?? defaultCenter;
    setState(() {
      isMissionRunning = false;
      isMissionPaused = false;
      missionStatus = 'STANDBY';
      missionSeconds = 0;
      dronePath = [];
      currentPathIndex = 0;
      // Return to positions around user's location
      dronePosition = LatLng(center.latitude + 0.002, center.longitude + 0.002);
      drone2Path = [];
      drone2PathIndex = 0;
      drone2Position = LatLng(center.latitude - 0.002, center.longitude - 0.002);
      drone3Path = [];
      drone3PathIndex = 0;
      drone3Position = LatLng(center.latitude + 0.004, center.longitude + 0.004);
      drone4Path = [];
      drone4PathIndex = 0;
      drone4Position = LatLng(center.latitude - 0.004, center.longitude + 0.004);
      drone5Path = [];
      drone5PathIndex = 0;
      drone5Position = LatLng(center.latitude + 0.004, center.longitude - 0.004);
      
    });

    // Update Firebase with final drone positions (Standby status)
    FirebaseService().updateDronePosition(
      droneId: 1,
      name: 'UAV-ALPHA-1',
      lat: dronePosition.latitude,
      lng: dronePosition.longitude,
      battery: drone1Battery,
      status: 'Standby',
    );
    FirebaseService().updateDronePosition(
      droneId: 2,
      name: 'UGV-DELTA-2',
      lat: drone2Position.latitude,
      lng: drone2Position.longitude,
      battery: drone2Battery,
      status: 'Standby',
    );
    FirebaseService().updateDronePosition(
      droneId: 3,
      name: 'UAV-CHARLIE-1',
      lat: drone3Position.latitude,
      lng: drone3Position.longitude,
      battery: drone3Battery,
      status: 'Standby',
    );
    FirebaseService().updateDronePosition(
      droneId: 4,
      name: 'UAV-DELTA-1',
      lat: drone4Position.latitude,
      lng: drone4Position.longitude,
      battery: drone4Battery,
      status: 'Standby',
    );
    FirebaseService().updateDronePosition(
      droneId: 5,
      name: 'UAV-ECHO-1',
      lat: drone5Position.latitude,
      lng: drone5Position.longitude,
      battery: drone5Battery,
      status: 'Standby',
    );

    _missionTimer?.cancel();
    _pathTimer?.cancel();
    _cbrnDetectionTimer?.cancel();
    _missionTimer = null;
    _pathTimer = null;
    _cbrnDetectionTimer = null;
  }

  void _startTimer() {
    _missionTimer?.cancel();
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          missionSeconds++;
          
          // Update altitude and speed for active drones based on operation mode
          if (isMissionRunning && !isMissionPaused) {
            if (selectedOpMode == 'Advance UAV Swarm Operation') {
              // All 5 drones active
              _updateDroneTelemetry(1);
              _updateDroneTelemetry(2);
              _updateDroneTelemetry(3);
              _updateDroneTelemetry(4);
              _updateDroneTelemetry(5);
            } else if (selectedOpMode == 'Multi-Drone Surveillance' || selectedOpMode == 'Advanced Mixed Operations') {
              // 2 drones active
              _updateDroneTelemetry(1);
              _updateDroneTelemetry(2);
            } else {
              // Manual mode: only first drone active
              _updateDroneTelemetry(1);
            }
            
            // Update system health and area status during mission
            _updateSystemHealth();
            _updateAreaStatus();
          } else {
            // When paused or stopped, reset to standby values
            _resetDroneTelemetry();
          }
        });
      }
    });
  }

  void _updateDroneTelemetry(int droneId) {
    switch (droneId) {
      case 1:
        if (drone1Battery > 0) drone1Battery--;
        // Fluctuate altitude between 300-340m
        drone1Altitude = 300 + (missionSeconds % 40);
        // Fluctuate speed between 35-45 km/h
        drone1Speed = 35 + (missionSeconds % 10);
        break;
      case 2:
        if (drone2Battery > 0) drone2Battery--;
        // Fluctuate altitude between 0-50m (UGV can go over small hills)
        drone2Altitude = (missionSeconds % 50);
        // Fluctuate speed between 8-15 km/h
        drone2Speed = 8 + (missionSeconds % 7);
        break;
      case 3:
        if (drone3Battery > 0) drone3Battery--;
        // Fluctuate altitude between 260-300m
        drone3Altitude = 260 + (missionSeconds % 40);
        // Fluctuate speed between 32-42 km/h
        drone3Speed = 32 + (missionSeconds % 10);
        break;
      case 4:
        if (drone4Battery > 0) drone4Battery--;
        // Fluctuate altitude between 280-320m
        drone4Altitude = 280 + (missionSeconds % 40);
        // Fluctuate speed between 34-44 km/h
        drone4Speed = 34 + (missionSeconds % 10);
        break;
      case 5:
        if (drone5Battery > 0) drone5Battery--;
        // Fluctuate altitude between 320-360m
        drone5Altitude = 320 + (missionSeconds % 40);
        // Fluctuate speed between 36-46 km/h
        drone5Speed = 36 + (missionSeconds % 10);
        break;
    }
  }

  void _resetDroneTelemetry() {
    // Reset to standby values when paused or stopped
    drone1Altitude = 320;
    drone1Speed = 0;
    drone2Altitude = 0;
    drone2Speed = 0;
    drone3Altitude = 280;
    drone3Speed = 0;
    drone4Altitude = 300;
    drone4Speed = 0;
    drone5Altitude = 340;
    drone5Speed = 0;
  }

  void _updateSystemHealth() {
    // Update system health values based on mission progress
    // MINI BTS: fluctuates between 0.80-0.90
    miniBtsHealth = 0.80 + ((missionSeconds % 10) / 100);
    
    // RECON LINK: fluctuates between 0.88-0.95
    reconLinkHealth = 0.88 + ((missionSeconds % 7) / 100);
    
    // AI SYSTEMS: fluctuates between 0.70-0.85
    aiSystemsHealth = 0.70 + ((missionSeconds % 15) / 100);
    
    // ENCRYPTION: stays at 1.0 (always optimal)
    encryptionHealth = 1.0;
    
    // UAV SWARM: fluctuates between 0.90-0.98
    uavSwarmHealth = 0.90 + ((missionSeconds % 8) / 100);
    
    // UGV FLEET: fluctuates between 0.82-0.92
    ugvFleetHealth = 0.82 + ((missionSeconds % 10) / 100);
  }

  void _updateAreaStatus() {
    // Update area status counts based on mission progress
    // Simulate changing risk levels as mission progresses
    final cycle = (missionSeconds % 30);
    
    if (cycle < 10) {
      // Low risk period
      highRiskCount = 1;
      mediumRiskCount = 2;
      safeZoneCount = 9;
    } else if (cycle < 20) {
      // Medium risk period
      highRiskCount = 2;
      mediumRiskCount = 3;
      safeZoneCount = 7;
    } else {
      // High risk period
      highRiskCount = 3;
      mediumRiskCount = 2;
      safeZoneCount = 7;
    }
  }

  void _pauseMission() {
    setState(() {
      isMissionPaused = true;
      missionStatus = 'PAUSED';
    });
    _missionTimer?.cancel();

    // Update Firebase with paused drone positions
    FirebaseService().updateDronePosition(
      droneId: 1,
      name: 'UAV-ALPHA-1',
      lat: dronePosition.latitude,
      lng: dronePosition.longitude,
      battery: drone1Battery,
      status: 'Paused',
    );
    FirebaseService().updateDronePosition(
      droneId: 2,
      name: 'UGV-DELTA-2',
      lat: drone2Position.latitude,
      lng: drone2Position.longitude,
      battery: drone2Battery,
      status: 'Paused',
    );
  }

  @override
  void dispose() {
    _missionTimer?.cancel();
    _pathTimer?.cancel();
    _cbrnDetectionTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANT untuk AutomaticKeepAliveClientMixin
    final bool isWide = MediaQuery.of(context).size.width >= 1100;

    if (isWide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: _buildLeftPanel()),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: _buildRightPanel()),
      ]);
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildLeftPanel(),
          const SizedBox(height: 20),
          _buildRightPanel(),
        ]),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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

    // Update both current location and drone positions (around user's location, not at it)
    currentLocation = userLocation;
    dronePosition = LatLng(userLocation.latitude + 0.002, userLocation.longitude + 0.002);
    drone2Position = LatLng(userLocation.latitude - 0.002, userLocation.longitude - 0.002);
    drone3Position = LatLng(userLocation.latitude + 0.004, userLocation.longitude + 0.004);
    drone4Position = LatLng(userLocation.latitude - 0.004, userLocation.longitude + 0.004);
    drone5Position = LatLng(userLocation.latitude + 0.004, userLocation.longitude - 0.004);

    // Move map to user's location
    mapController.move(userLocation, 16.0);

    // Trigger rebuild to update drone markers
    setState(() {});
  }

  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(title: 'MISSION STATUS', child: Row(children: [
          _StatItem(label: 'Active Units', value: '3'),
          _StatItem(label: 'Critical Alerts', value: '1', isCritical: true),
          _StatItem(label: 'Duration', value: _formatDuration(missionSeconds)),
          _StatItem(label: 'Status', value: missionStatus, isStatus: true),
        ])),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Expanded(child: _MissionButton(label: 'START', color: const Color(0xFF38FF9C), onPressed: isMissionRunning ? null : _startMission)),
          const SizedBox(width: 12),
          Expanded(child: _MissionButton(label: 'PAUSE', color: const Color(0xFFFFB020), onPressed: (isMissionRunning && !isMissionPaused) ? _pauseMission : null)),
          const SizedBox(width: 12),
          Expanded(child: _MissionButton(label: 'STOP', color: const Color(0xFFFF4D4F), onPressed: (isMissionRunning || isMissionPaused) ? _stopMission : null)),
        ]),
        const SizedBox(height: 16),
        _panel(title: 'OPERATION MODE', child: Column(children: [
          _OpModeItem(title: 'Multi-Drone Surveillance', desc: '2 Multi-Drones with leader-follower...', active: selectedOpMode == 'Multi-Drone Surveillance', onTap: () => setState(() => selectedOpMode = 'Multi-Drone Surveillance')),
          const SizedBox(height: 8),
          _OpModeItem(title: 'Advanced Mixed Operations', desc: 'Combined UAV/UGV coordination.', active: selectedOpMode == 'Advanced Mixed Operations', onTap: () => setState(() => selectedOpMode = 'Advanced Mixed Operations')),
          const SizedBox(height: 8),
          _OpModeItem(title: 'Advance UAV Swarm Operation', desc: '5 UAV swarm + 1 legged robot for large-scale with difficult terrain', active: selectedOpMode == 'Advance UAV Swarm Operation', onTap: () => setState(() => selectedOpMode = 'Advance UAV Swarm Operation')),
          const SizedBox(height: 8),
          _OpModeItem(title: 'Manual Remote Operation', desc: 'Operator-controlled robots with manual override capability for precise operations', active: selectedOpMode == 'Manual Remote Operation', onTap: () => setState(() => selectedOpMode = 'Manual Remote Operation')),
        ])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _panel(title: 'MOVEMENT PATTERN', child: SizedBox(height: 190, child: Column(children: [
            _MovementItem(label: 'Spiral', active: selectedMovement == 'Spiral', onTap: () => setState(() => selectedMovement = 'Spiral')),
            _MovementItem(label: 'Grid', active: selectedMovement == 'Grid', onTap: () => setState(() => selectedMovement = 'Grid')),
            _MovementItem(label: 'Zigzag', active: selectedMovement == 'Zigzag', onTap: () => setState(() => selectedMovement = 'Zigzag')),
            _MovementItem(label: 'Random', active: selectedMovement == 'Random', onTap: () => setState(() => selectedMovement = 'Random')),
            _MovementItem(label: 'Manual Control', active: selectedMovement == 'Manual Control', onTap: () => setState(() => selectedMovement = 'Manual Control')),
          ])))),
          const SizedBox(width: 16),
          Expanded(child: _panel(title: 'AREA STATUS', child: SizedBox(height: 190, child: Column(children: [
            _AreaStatusRow(label: 'High Risk', count: '$highRiskCount', percent: '${((highRiskCount / 12) * 100).toInt()}%', color: const Color(0xFFFF4D4F), value: highRiskCount / 12),
            const SizedBox(height: 12),
            _AreaStatusRow(label: 'Medium Risk', count: '$mediumRiskCount', percent: '${((mediumRiskCount / 12) * 100).toInt()}%', color: const Color(0xFFFFB020), value: mediumRiskCount / 12),
            const SizedBox(height: 12),
            _AreaStatusRow(label: 'Safe Zone', count: '$safeZoneCount', percent: '${((safeZoneCount / 12) * 100).toInt()}%', color: const Color(0xFF38FF9C), value: safeZoneCount / 12),
          ])))),
        ]),
        const SizedBox(height: 16),
        _panel(
          title: 'RECENT ACTIVITY',
          child: Column(
            children: [
              if (activityLog.isEmpty)
                const Text('No recent activity', style: TextStyle(color: Color(0xFF7C8B85), fontSize: 12))
              else
                ...activityLog.take(5).map((log) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            log.type == 'critical'
                                ? Icons.error
                                : log.type == 'warning'
                                    ? Icons.warning
                                    : Icons.check_circle,
                            color: log.type == 'critical'
                                ? const Color(0xFFFF4D4F)
                                : log.type == 'warning'
                                    ? const Color(0xFFFFB020)
                                    : const Color(0xFF38FF9C),
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(log.message, style: const TextStyle(fontSize: 12))),
                          Text(log.time, style: const TextStyle(fontSize: 11, color: Color(0xFF7C8B85))),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(children: [
      _buildMapArea(),
      const SizedBox(height: 16),
      _buildInfoUAVPanel(),
      const SizedBox(height: 16),
      _buildTelemetryPanel(),
    ]);
  }

  Widget _buildInfoUAVPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF101915), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1C2A24))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('INFO UAV', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Active Units & Telemetry', style: TextStyle(fontSize: 12, color: Color(0xFF7C8B85))),
          ])),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: const Text('Focus')),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 140, child: Row(children: [
          Expanded(child: _InfoUAVItem(name: 'UAV-ALPHA-1', type: 'UAV', status: isMissionRunning ? 'Active' : 'Standby', battery: '$drone1Battery%', altitude: '${isMissionRunning ? drone1Altitude : 320} m', speed: '${isMissionRunning ? drone1Speed : 0} km/h')),
          const SizedBox(width: 12),
          Expanded(child: _InfoUAVItem(name: 'UGV-DELTA-2', type: 'UGV', status: isMissionRunning ? 'Active' : 'Standby', battery: '$drone2Battery%', altitude: '${isMissionRunning ? drone2Altitude : 0} m', speed: '${isMissionRunning ? drone2Speed : 0} km/h')),
          const SizedBox(width: 12),
          Expanded(child: _InfoUAVItem(name: 'UAV-BRAVO-1', type: 'UAV', status: isMissionRunning ? 'Active' : 'Standby', battery: '$drone3Battery%', altitude: '${isMissionRunning ? drone3Altitude : 280} m', speed: '${isMissionRunning ? drone3Speed : 0} km/h')),
        ])),
      ]),
    );
  }

  Widget _InfoUAVItem({required String name, required String type, required String status, required String battery, required String altitude, required String speed}) {
    Color statusColor = status == 'Active' ? const Color(0xFF38FF9C) : const Color(0xFFFFB020);
    
    // Parse battery value and determine color
    final batteryValue = int.tryParse(battery.replaceAll('%', '')) ?? 100;
    Color batteryColor;
    if (batteryValue > 50) {
      batteryColor = const Color(0xFF38FF9C); // Green
    } else if (batteryValue > 20) {
      batteryColor = const Color(0xFFFFB020); // Orange
    } else {
      batteryColor = const Color(0xFFFF4D4F); // Red
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1C2A24), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Text('$type · $status', style: const TextStyle(fontSize: 11, color: Color(0xFF7C8B85))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Bat: $battery', style: TextStyle(fontSize: 10, color: batteryColor, fontWeight: FontWeight.w600)),
          Text('Alt: $altitude', style: const TextStyle(fontSize: 10, color: Color(0xFF7C8B85))),
          Text('Spd: $speed', style: const TextStyle(fontSize: 10, color: Color(0xFF7C8B85))),
        ]),
      ]),
    );
  }

  Widget _AreaStatusRow({required String label, required String count, required String percent, required Color color, required double value}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFE6F4EE))),
        Text('$count ($percent)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value, backgroundColor: const Color(0xFF1C2A24), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)),
    ]);
  }

  Widget _buildMapArea() {
    return SizedBox(
      height: 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(initialCenter: currentLocation ?? defaultCenter, initialZoom: 16.0),
              children: [
                _tileLayer(),
                if (dronePath.length > 1) _pathLayer(),
                if (cbrnHotspots.isNotEmpty) _cbrnHotspotsLayer(),
                _droneMarker(),
                if (currentLocation != null) _currentLocationMarker(),
              ],
            ),
            // Drone name card overlay
            if (selectedDroneName != null)
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101915),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38FF9C), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38FF9C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SELECTED DRONE',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedDroneName!,
                        style: const TextStyle(
                          color: Color(0xFF38FF9C),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDroneType(selectedDroneName!),
                        style: const TextStyle(
                          color: Color(0xFF7C8B85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDroneType(String droneName) {
    if (droneName.startsWith('UAV')) return 'Unmanned Aerial Vehicle';
    if (droneName.startsWith('UGV')) return 'Unmanned Ground Vehicle';
    return 'Unknown Type';
  }

  Widget _pathLayer() {
    List<Polyline> polylines = [
      // First drone path (blue)
      if (dronePath.length > 1)
        Polyline(
          points: dronePath,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
      // Second drone path (blue)
      if (drone2Path.length > 1)
        Polyline(
          points: drone2Path,
          strokeWidth: 3,
          color: const Color(0xFF00D4FF).withOpacity(0.6),
        ),
    ];

    // Add paths for swarm mode
    if (selectedOpMode == 'Advance UAV Swarm Operation') {
      polylines.addAll([
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
      ]);
    }

    return PolylineLayer(polylines: polylines);
  }

  Widget _droneMarker() {
    List<Marker> markers = [
      // First drone (blue) - UAV-ALPHA-1
      Marker(
        point: dronePosition,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedDroneName = selectedDroneName == 'UAV-ALPHA-1' ? null : 'UAV-ALPHA-1';
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: selectedDroneName == 'UAV-ALPHA-1' ? const Color(0xFF38FF9C) : const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
      ),
      // Second drone (blue) - UGV-DELTA-2
      Marker(
        point: drone2Position,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedDroneName = selectedDroneName == 'UGV-DELTA-2' ? null : 'UGV-DELTA-2';
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: selectedDroneName == 'UGV-DELTA-2' ? const Color(0xFF38FF9C) : const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.flight, color: Colors.black, size: 24),
          ),
        ),
      ),
    ];

    // Add additional drones for swarm mode
    if (selectedOpMode == 'Advance UAV Swarm Operation') {
      markers.addAll([
        // Third drone (blue) - UAV-CHARLIE-1
        Marker(
          point: drone3Position,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedDroneName = selectedDroneName == 'UAV-CHARLIE-1' ? null : 'UAV-CHARLIE-1';
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: selectedDroneName == 'UAV-CHARLIE-1' ? const Color(0xFF38FF9C) : const Color(0xFF00D4FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.flight, color: Colors.black, size: 24),
            ),
          ),
        ),
        // Fourth drone (blue) - UAV-DELTA-1
        Marker(
          point: drone4Position,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedDroneName = selectedDroneName == 'UAV-DELTA-1' ? null : 'UAV-DELTA-1';
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: selectedDroneName == 'UAV-DELTA-1' ? const Color(0xFF38FF9C) : const Color(0xFF00D4FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.flight, color: Colors.black, size: 24),
            ),
          ),
        ),
        // Fifth drone (blue) - UAV-ECHO-1
        Marker(
          point: drone5Position,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedDroneName = selectedDroneName == 'UAV-ECHO-1' ? null : 'UAV-ECHO-1';
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: selectedDroneName == 'UAV-ECHO-1' ? const Color(0xFF38FF9C) : const Color(0xFF00D4FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.flight, color: Colors.black, size: 24),
            ),
          ),
        ),
      ]);
    }

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
    
    return MarkerLayer(markers: markers);
  }

  Widget _evacuationRouteLayer() {
    List<Polyline> polylines = [];
    
    for (final route in evacuationRoutes) {
      if (route.routePath.isNotEmpty) {
        // Use bright lime green colors for evacuation routes - distinct from all other elements
        // Blue drone paths: 0xFF00D4FF (Cyan)
        // Chemical substances: 0xFFFFB020 (Orange)
        // Biological substances: 0xFF9C27B0 (Purple)
        // Radiological substances: 0xFF00D4FF (Cyan)
        // Nuclear substances: 0xFFFF4D4F (Red)
        Color routeColor = route.status == 'Completed' ? const Color(0xFF00C853) : // Green
                          route.status == 'In Progress' ? const Color(0xFF76FF03) : // Bright lime green
                          const Color(0xFF64DD17); // Lime green
        
        polylines.add(
          Polyline(
            points: route.routePath,
            strokeWidth: 6, // Thicker than drone paths (3)
            color: routeColor.withOpacity(1.0),
            pattern: StrokePattern.dashed(segments: [10, 5]), // Dashed pattern to make it more visible
          ),
        );
      }
    }
    
    return PolylineLayer(polylines: polylines);
  }

  Widget _evacuationPointMarker() {
    if (selectedEvacuationPoint == null) {
      return const SizedBox.shrink();
    }
    
    return MarkerLayer(
      markers: [
        Marker(
          point: selectedEvacuationPoint!,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _showEvacuationPointDialog();
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF76FF03).withOpacity(0.2),
                    border: Border.all(color: const Color(0xFF76FF03), width: 2),
                  ),
                ),
                // Inner circle
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF76FF03),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF76FF03).withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.location_on, color: Colors.black, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEvacuationPointDialog() {
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
                color: const Color(0xFF76FF03),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAFE EVACUATION POINT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Designated Safe Zone',
                    style: TextStyle(color: Color(0xFF76FF03), fontSize: 12),
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
            _buildDetailRow('Latitude', selectedEvacuationPoint!.latitude.toStringAsFixed(6), const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildDetailRow('Longitude', selectedEvacuationPoint!.longitude.toStringAsFixed(6), const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildDetailRow('Status', 'SAFE ZONE', const Color(0xFF76FF03)),
            const SizedBox(height: 8),
            _buildDetailRow('Active Routes', '${evacuationRoutes.length}', const Color(0xFF7C8B85)),
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
              mapController.move(selectedEvacuationPoint!, 18.0);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0)),
            child: const Text('Focus', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
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
            _buildDetailRow('Severity', hotspot.severity.toUpperCase(), _getSeverityColor(hotspot.severity)),
            const SizedBox(height: 8),
            _buildDetailRow('Detected By', hotspot.detectedBy, const Color(0xFF00D4FF)),
            const SizedBox(height: 8),
            _buildDetailRow('Detection Time', _formatDateTime(hotspot.detectedTime), const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildDetailRow('Detected Value', '${hotspot.detectedValue.toStringAsFixed(2)} ${hotspot.unit}', _getColorForCBRNType(hotspot.type)),
            const SizedBox(height: 8),
            _buildDetailRow('Threshold', '${hotspot.threshold.toStringAsFixed(2)} ${hotspot.unit}', const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildDetailRow('Status', hotspot.detectedValue >= hotspot.threshold ? 'ABOVE THRESHOLD' : 'BELOW THRESHOLD', hotspot.detectedValue >= hotspot.threshold ? const Color(0xFFFF4D4F) : const Color(0xFF38FF9C)),
            const SizedBox(height: 8),
            _buildDetailRow('Radius', '${(hotspot.radius * 100000).toInt()} m', const Color(0xFF7C8B85)),
            const SizedBox(height: 8),
            _buildDetailRow('Position', '${hotspot.position.latitude.toStringAsFixed(6)}, ${hotspot.position.longitude.toStringAsFixed(6)}', const Color(0xFF7C8B85)),
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

  Widget _buildDetailRow(String label, String value, Color valueColor) {
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

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFFF4D4F);
      case 'high':
        return const Color(0xFFFFB020);
      case 'medium':
        return const Color(0xFF38FF9C);
      default:
        return const Color(0xFF7C8B85);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }


  Widget _tileLayer() {
    return TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'com.example.cbrn4');
  }

  Widget _buildTelemetryPanel() {
    final List<SystemComponent> components = [
      SystemComponent(name: 'MINI BTS', value: miniBtsHealth, hasWarning: miniBtsHealth < 0.82),
      SystemComponent(name: 'RECON LINK', value: reconLinkHealth, hasWarning: reconLinkHealth < 0.90),
      SystemComponent(name: 'AI SYSTEMS', value: aiSystemsHealth, hasWarning: aiSystemsHealth < 0.75),
      SystemComponent(name: 'ENCRYPTION', value: encryptionHealth, hasWarning: encryptionHealth < 0.98),
      SystemComponent(name: 'UAV SWARM', value: uavSwarmHealth, hasWarning: uavSwarmHealth < 0.92),
      SystemComponent(name: 'UGV FLEET', value: ugvFleetHealth, hasWarning: ugvFleetHealth < 0.85),
    ];
    
    // Calculate overall health
    final overallHealth = (miniBtsHealth + reconLinkHealth + aiSystemsHealth + encryptionHealth + uavSwarmHealth + ugvFleetHealth) / 6;
    final healthStatus = overallHealth >= 0.90 ? 'OPTIMAL' : overallHealth >= 0.80 ? 'GOOD' : overallHealth >= 0.70 ? 'WARNING' : 'CRITICAL';
    final healthColor = overallHealth >= 0.90 ? const Color(0xFF38FF9C) : overallHealth >= 0.80 ? const Color(0xFF2F80ED) : overallHealth >= 0.70 ? const Color(0xFFFFB020) : const Color(0xFFFF4D4F);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF101915), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1C2A24))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SYSTEM HEALTH', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Overall System Performance Indicator', style: TextStyle(fontSize: 12, color: Color(0xFF7C8B85))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: healthColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(healthStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: healthColor))),
        ]),
        const SizedBox(height: 16),
        Column(children: components.map((comp) => _SystemHealthRow(name: comp.name, value: comp.value, hasWarning: comp.hasWarning)).toList()),
      ]),
    );
  }

  Widget _SystemHealthRow({required String name, required double value, required bool hasWarning}) {
    Color barColor = hasWarning ? const Color(0xFFFFB020) : const Color(0xFF38FF9C);
    return Column(children: [
      Row(children: [
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: Color(0xFFE6F4EE)))),
        Icon(hasWarning ? Icons.warning : Icons.check_circle, color: hasWarning ? const Color(0xFFFFB020) : const Color(0xFF38FF9C), size: 18),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value, backgroundColor: const Color(0xFF1C2A24), valueColor: AlwaysStoppedAnimation<Color>(barColor), minHeight: 6)),
      const SizedBox(height: 12),
    ]);
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF101915), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1C2A24))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10), child]));
  }

  Widget _StatItem({required String label, required String value, bool isCritical = false, bool isStatus = false}) {
    Color valueColor = Colors.white;
    if (isCritical) valueColor = const Color(0xFFFF4D4F);
    if (isStatus && value == 'STANDBY') valueColor = const Color(0xFFFFB020);
    if (isStatus && value == 'ACTIVE') valueColor = const Color(0xFF38FF9C);
    if (isStatus && value == 'PAUSED') valueColor = const Color(0xFFFFB020);
    return Padding(padding: const EdgeInsets.all(8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7C8B85))), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: valueColor))]));
  }

  Widget _OpModeItem({required String title, required String desc, required bool active, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: active ? const Color(0xFF16221C) : Colors.transparent, border: Border.all(color: active ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24)), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.check_circle, color: active ? const Color(0xFF38FF9C) : const Color(0xFF7C8B85), size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF7C8B85)))])), if (active) const Text('ACTIVE', style: TextStyle(fontSize: 10, color: Color(0xFF38FF9C)))])));
  }

  Widget _MovementItem({required String label, required bool active, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: active ? const Color(0xFF38FF9C).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: active ? const Color(0xFF38FF9C) : Colors.transparent)), child: Row(children: [Icon(Icons.circle, size: 8, color: active ? const Color(0xFF38FF9C) : const Color(0xFF7C8B85)), const SizedBox(width: 8), Text(label, style: TextStyle(color: active ? const Color(0xFF38FF9C) : const Color(0xFFE6F4EE)))])));
  }

  Widget _MissionButton({required String label, required Color color, VoidCallback? onPressed}) {
    return ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: onPressed == null ? const Color(0xFF1C2A24) : color, foregroundColor: onPressed == null ? const Color(0xFF7C8B85) : Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), textStyle: const TextStyle(fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: Text(label));
  }

  Widget _ActivityItem({required String message, required String type}) {
    IconData icon;
    Color iconColor;
    switch (type) {
      case 'critical':
        icon = Icons.error;
        iconColor = const Color(0xFFFF4D4F);
        break;
      case 'warning':
        icon = Icons.warning;
        iconColor = const Color(0xFFFFB020);
        break;
      case 'success':
        icon = Icons.check_circle;
        iconColor = const Color(0xFF38FF9C);
        break;
      case 'info':
        icon = Icons.info;
        iconColor = const Color(0xFF38A1FF);
        break;
      default:
        icon = Icons.info;
        iconColor = const Color(0xFF7C8B85);
    }
    return Row(children: [
      Icon(icon, color: iconColor, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
    ]);
  }
}

class SystemComponent {
  final String name;
  final double value;
  final bool hasWarning;
  SystemComponent({required this.name, required this.value, required this.hasWarning});
}


class ActivityLog {
  final String message;
  final String type;
  final String time;

  ActivityLog({
    required this.message,
    required this.type,
    required this.time,
  });
}

