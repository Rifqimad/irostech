import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class DroneState extends ChangeNotifier {
  // Drone positions
  LatLng dronePosition = const LatLng(51.505, -0.09);
  LatLng drone2Position = const LatLng(51.505, -0.09);
  LatLng drone3Position = const LatLng(51.505, -0.09);
  LatLng drone4Position = const LatLng(51.505, -0.09);
  LatLng drone5Position = const LatLng(51.505, -0.09);

  // Drone paths
  List<LatLng> dronePath = [];
  List<LatLng> drone2Path = [];
  List<LatLng> drone3Path = [];
  List<LatLng> drone4Path = [];
  List<LatLng> drone5Path = [];

  // Path indices
  int currentPathIndex = 0;
  int drone2PathIndex = 0;
  int drone3PathIndex = 0;
  int drone4PathIndex = 0;
  int drone5PathIndex = 0;

  // Mission state
  bool isMissionRunning = false;
  bool isMissionPaused = false;
  String missionStatus = 'STANDBY';
  String selectedOpMode = 'Multi-Drone Surveillance';
  String selectedMovement = 'Manual Control';
  int missionSeconds = 0;

  // Hazardous zones
  HazardousZone? redZone;
  HazardousZone? greenZone;

  // Activity log
  final List<ActivityLog> activityLog = [];

  // Detected substances
  final List<DetectedSubstance> detectedSubstances = [];

  // Timer
  Timer? _missionTimer;
  Timer? _pathTimer;

  // Update drone position
  void updateDronePosition(int droneIndex, LatLng position) {
    switch (droneIndex) {
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
    notifyListeners();
  }

  // Update drone path
  void updateDronePath(int droneIndex, List<LatLng> path) {
    switch (droneIndex) {
      case 1:
        dronePath = path;
        currentPathIndex = 0;
        break;
      case 2:
        drone2Path = path;
        drone2PathIndex = 0;
        break;
      case 3:
        drone3Path = path;
        drone3PathIndex = 0;
        break;
      case 4:
        drone4Path = path;
        drone4PathIndex = 0;
        break;
      case 5:
        drone5Path = path;
        drone5PathIndex = 0;
        break;
    }
    notifyListeners();
  }

  // Start mission
  void startMission() {
    isMissionRunning = true;
    isMissionPaused = false;
    missionStatus = 'ACTIVE';
    missionSeconds = 0;
    notifyListeners();
    _startTimer();
    _startPathAnimation();
  }

  // Stop mission
  void stopMission() {
    isMissionRunning = false;
    isMissionPaused = false;
    missionStatus = 'STANDBY';
    missionSeconds = 0;
    dronePath = [];
    drone2Path = [];
    drone3Path = [];
    drone4Path = [];
    drone5Path = [];
    currentPathIndex = 0;
    drone2PathIndex = 0;
    drone3PathIndex = 0;
    drone4PathIndex = 0;
    drone5PathIndex = 0;
    _missionTimer?.cancel();
    _pathTimer?.cancel();
    _missionTimer = null;
    _pathTimer = null;
    notifyListeners();
  }

  // Pause mission
  void pauseMission() {
    isMissionPaused = true;
    missionStatus = 'PAUSED';
    _missionTimer?.cancel();
    notifyListeners();
  }

  // Resume mission
  void resumeMission() {
    isMissionPaused = false;
    missionStatus = 'ACTIVE';
    _startTimer();
    _startPathAnimation();
    notifyListeners();
  }

  // Set operation mode
  void setOperationMode(String mode) {
    selectedOpMode = mode;
    notifyListeners();
  }

  // Set movement pattern
  void setMovementPattern(String pattern) {
    selectedMovement = pattern;
    notifyListeners();
  }

  // Add activity log
  void addActivityLog(ActivityLog log) {
    activityLog.insert(0, log);
    notifyListeners();
  }

  // Add detected substance
  void addDetectedSubstance(DetectedSubstance substance) {
    detectedSubstances.add(substance);
    notifyListeners();
  }

  // Start timer
  void _startTimer() {
    _missionTimer?.cancel();
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      missionSeconds++;
      notifyListeners();
    });
  }

  // Start path animation
  void _startPathAnimation() {
    _pathTimer?.cancel();
    if (selectedMovement == 'Manual Control') return;

    _pathTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!isMissionRunning || isMissionPaused) return;

      // Animate drones based on operation mode
      if (selectedOpMode == 'Advance UAV Swarm Operation') {
        _animateDrone(1, dronePath, currentPathIndex, dronePosition);
        _animateDrone(2, drone2Path, drone2PathIndex, drone2Position);
        _animateDrone(3, drone3Path, drone3PathIndex, drone3Position);
        _animateDrone(4, drone4Path, drone4PathIndex, drone4Position);
        _animateDrone(5, drone5Path, drone5PathIndex, drone5Position);
      } else if (selectedOpMode == 'Multi-Drone Surveillance' || selectedOpMode == 'Advanced Mixed Operations') {
        _animateDrone(1, dronePath, currentPathIndex, dronePosition);
        _animateDrone(2, drone2Path, drone2PathIndex, drone2Position);
      } else {
        _animateDrone(1, dronePath, currentPathIndex, dronePosition);
      }
    });
  }

  // Animate individual drone
  void _animateDrone(int droneIndex, List<LatLng> path, int pathIndex, LatLng currentPosition) {
    if (pathIndex < path.length - 1) {
      switch (droneIndex) {
        case 1:
          currentPathIndex++;
          dronePosition = path[currentPathIndex];
          break;
        case 2:
          drone2PathIndex++;
          drone2Position = path[drone2PathIndex];
          break;
        case 3:
          drone3PathIndex++;
          drone3Position = path[drone3PathIndex];
          break;
        case 4:
          drone4PathIndex++;
          drone4Position = path[drone4PathIndex];
          break;
        case 5:
          drone5PathIndex++;
          drone5Position = path[drone5PathIndex];
          break;
      }
      notifyListeners();
    } else {
      switch (droneIndex) {
        case 1:
          currentPathIndex = 0;
          break;
        case 2:
          drone2PathIndex = 0;
          break;
        case 3:
          drone3PathIndex = 0;
          break;
        case 4:
          drone4PathIndex = 0;
          break;
        case 5:
          drone5PathIndex = 0;
          break;
      }
    }
  }

  @override
  void dispose() {
    _missionTimer?.cancel();
    _pathTimer?.cancel();
    super.dispose();
  }
}

class DetectedSubstance {
  final String name, type, severity, time;
  final double lat, lng;
  DetectedSubstance({required this.name, required this.type, required this.lat, required this.lng, required this.severity, required this.time});
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
