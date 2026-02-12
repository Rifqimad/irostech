// lib/services/firebase_service.dart

import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Update mission status
  Future<void> updateMissionStatus({
    required bool isRunning,
    required bool isPaused,
    required String pattern,
  }) async {
    await _database.child('mission').set({
      'isRunning': isRunning,
      'isPaused': isPaused,
      'pattern': pattern,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  // Get mission status stream
  Stream<Map<String, dynamic>> getMissionStatus() {
    return _database.child('mission').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {
          'isRunning': false,
          'isPaused': false,
          'pattern': 'Grid',
        };
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  // Update drone position
  Future<void> updateDronePosition({
    required int droneId,
    required String name,
    required double lat,
    required double lng,
    required int battery,
    required String status,
  }) async {
    await _database.child('drones/drone$droneId').set({
      'id': droneId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'battery': battery,
      'status': status,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  // Get drone positions stream
  Stream<Map<String, dynamic>> getDronePositions() {
    return _database.child('drones').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {};
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }
}