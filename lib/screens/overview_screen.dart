// lib/screens/overview_screen.dart

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

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final MapController mapController = MapController();
  final LatLng defaultCenter = const LatLng(51.505, -0.09);
  LatLng? currentLocation;

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
  LatLng dronePosition = const LatLng(51.505, -0.09);  // Detected hazardous substances
  final List<DetectedSubstance> detectedSubstances = [
    DetectedSubstance(name: 'Chlorine', type: 'chemical', lat: 51.508, lng: -0.092, severity: 'high', time: '10:23'),
    DetectedSubstance(name: 'Cesium-137', type: 'radiological', lat: 51.502, lng: -0.088, severity: 'critical', time: '09:45'),
    DetectedSubstance(name: 'VX', type: 'chemical', lat: 51.507, lng: -0.095, severity: 'critical', time: '11:12'),
    DetectedSubstance(name: 'Anthrax', type: 'biological', lat: 51.504, lng: -0.090, severity: 'high', time: '08:30'),
  ];

  // Simulated hazardous zones for drone detection
  // Zones positioned near Bandung, Indonesia (approx: -6.9, 107.6)
  final List<HazardousZone> hazardousZones = [
    HazardousZone(
      name: 'Chemical Leak Zone A',
      center: const LatLng(-6.9215, 107.6085),
      radiusKm: 0.3,
      severity: 'critical',
      substanceType: 'chemical',
      detected: false,
    ),
    HazardousZone(
      name: 'Radiation Hotspot B',
      center: const LatLng(-6.9205, 107.6065),
      radiusKm: 0.25,
      severity: 'high',
      substanceType: 'radiological',
      detected: false,
    ),
    HazardousZone(
      name: 'Biological Contamination C',
      center: const LatLng(-6.9225, 107.6105),
      radiusKm: 0.35,
      severity: 'medium',
      substanceType: 'biological',
      detected: false,
    ),
    HazardousZone(
      name: 'Nuclear Residue D',
      center: const LatLng(-6.9195, 107.6075),
      radiusKm: 0.2,
      severity: 'low',
      substanceType: 'nuclear',
      detected: false,
    ),
  ];

  // Recent activity log
  final List<ActivityLog> activityLog = [];

  Timer? _missionTimer;

  void _startMission() {
    final center = currentLocation ?? defaultCenter;
    setState(() {
      isMissionRunning = true;
      isMissionPaused = false;
      missionStatus = 'ACTIVE';
      missionSeconds = 0;
      dronePath = _generatePath(selectedMovement, center);
      currentPathIndex = 0;
      dronePosition = dronePath.isNotEmpty ? dronePath[0] : center;
    });
    _startTimer();
    _startPathAnimation();
  }

  List<LatLng> _generatePath(String pattern, LatLng center) {
    List<LatLng> path = [];
    final double latStep = 0.001;
    final double lngStep = 0.001;

    switch (pattern) {
      case 'Grid':
        // Grid pattern - back and forth
        for (int i = 0; i < 5; i++) {
          path.add(LatLng(center.latitude + i * latStep, center.longitude));
          path.add(LatLng(center.latitude + i * latStep, center.longitude + 4 * lngStep));
          if (i < 4) {
            path.add(LatLng(center.latitude + (i + 1) * latStep, center.longitude + 4 * lngStep));
            path.add(LatLng(center.latitude + (i + 1) * latStep, center.longitude));
          }
        }
        break;
      case 'Zigzag':
        // Zigzag pattern - alternating diagonal
        for (int i = 0; i < 10; i++) {
          double lat = center.latitude + (i * latStep * 0.5);
          double lng = center.longitude + (i % 2 == 0 ? 0 : 3 * lngStep);
          path.add(LatLng(lat, lng));
        }
        break;
      case 'Spiral':
        // Spiral pattern - expanding circle
        for (int i = 0; i < 50; i++) {
          double angle = i * 0.3;
          double radius = 0.002 + (i * 0.0003);
          path.add(LatLng(
            center.latitude + radius * math.cos(angle),
            center.longitude + radius * math.sin(angle),
          ));
        }
        break;
      case 'Random':
        // Random pattern - pseudo random waypoints
        path.add(center);
        for (int i = 0; i < 20; i++) {
          path.add(LatLng(
            center.latitude + (i * 0.0005) + (i % 3 == 0 ? 0.002 : -0.001),
            center.longitude + (i * 0.0005) + (i % 5 == 0 ? 0.003 : -0.002),
          ));
        }
        break;
      case 'Manual Control':
        // Manual - just stay at center
        path.add(center);
        break;
      default:
        path.add(center);
    }

    return path;
  }

  void _startPathAnimation() {
    _pathTimer?.cancel();
    if (selectedMovement == 'Manual Control') return;

    _pathTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!isMissionRunning || isMissionPaused) return;

      if (currentPathIndex < dronePath.length - 1) {
        setState(() {
          currentPathIndex++;
          dronePosition = dronePath[currentPathIndex];
        });
        // Center map on drone
        mapController.move(dronePosition, 16.0);

        // Check for hazardous zone detection
        _checkHazardousZones();
      } else {
        // Path complete - loop
        currentPathIndex = 0;
      }
    });
  }

  void _checkHazardousZones() {
    for (var zone in hazardousZones) {
      if (zone.detected) continue; // Already detected

      // Calculate distance between drone and zone center
      final distance = Geolocator.distanceBetween(
        dronePosition.latitude,
        dronePosition.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      // If drone is within zone radius, mark as detected
      if (distance <= zone.radiusKm * 1000) {
        setState(() {
          zone.detected = true;

          // If critical zone (red), add detected substance to database
          if (zone.severity == 'critical') {
            // Find substance matching zone type
            final now = DateTime.now();
            final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

            // Add to detected substances list
            detectedSubstances.add(DetectedSubstance(
              name: _getSubstanceName(zone.substanceType),
              type: zone.substanceType,
              lat: zone.center.latitude,
              lng: zone.center.longitude,
              severity: 'critical',
              time: timeStr,
            ));

            // Add activity log entry
            activityLog.insert(
              0,
              ActivityLog(
                message: 'Hazardous substance detected: ${_getSubstanceName(zone.substanceType)} (${zone.name})',
                type: 'critical',
                time: timeStr,
              ),
            );
          } else {
            // Add activity log entry for non-critical zones
            final now = DateTime.now();
            final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
            activityLog.insert(
              0,
              ActivityLog(
                message: 'Hazardous zone detected: ${zone.name}',
                type: 'warning',
                time: timeStr,
              ),
            );
          }
        });
      }
    }
  }

  String _getSubstanceName(String type) {
    switch (type) {
      case 'chemical':
        return 'Sarin';
      case 'biological':
        return 'Anthrax';
      case 'radiological':
        return 'Cesium-137';
      case 'nuclear':
        return 'Uranium-235';
      default:
        return 'Unknown Substance';
    }
  }

  void _stopMission() {
    setState(() {
      isMissionRunning = false;
      isMissionPaused = false;
      missionStatus = 'STANDBY';
      missionSeconds = 0;
      dronePath = [];
      currentPathIndex = 0;
      dronePosition = defaultCenter;
    });
    _missionTimer?.cancel();
    _pathTimer?.cancel();
    _missionTimer = null;
    _pathTimer = null;
  }

  void _startTimer() {
    _missionTimer?.cancel();
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          missionSeconds++;
        });
      }
    });
  }

  void _pauseMission() {
    setState(() {
      isMissionPaused = true;
      missionStatus = 'PAUSED';
    });
    _missionTimer?.cancel();
  }

  @override
  void dispose() {
    _missionTimer?.cancel();
    _pathTimer?.cancel();
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

    // Update both current location and drone position
    currentLocation = userLocation;
    dronePosition = userLocation;

    // Move map to user's location
    mapController.move(userLocation, 16.0);

    // Trigger rebuild to update drone marker
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
            _AreaStatusRow(label: 'High Risk', count: '2', percent: '12%', color: const Color(0xFFFF4D4F), value: 0.12),
            const SizedBox(height: 12),
            _AreaStatusRow(label: 'Medium Risk', count: '2', percent: '18%', color: const Color(0xFFFFB020), value: 0.18),
            const SizedBox(height: 12),
            _AreaStatusRow(label: 'Safe Zone', count: '8', percent: '70%', color: const Color(0xFF38FF9C), value: 0.70),
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
          Expanded(child: _InfoUAVItem(name: 'UAV-ALPHA-1', type: 'UAV', status: 'Active', battery: '98%', altitude: '320 m', speed: '41 km/h')),
          const SizedBox(width: 12),
          Expanded(child: _InfoUAVItem(name: 'UGV-DELTA-2', type: 'UGV', status: 'Maintenance', battery: '85%', altitude: '0 m', speed: '12 km/h')),
          const SizedBox(width: 12),
          Expanded(child: _InfoUAVItem(name: 'UAV-BRAVO-1', type: 'UAV', status: 'Active', battery: '92%', altitude: '280 m', speed: '38 km/h')),
        ])),
      ]),
    );
  }

  Widget _InfoUAVItem({required String name, required String type, required String status, required String battery, required String altitude, required String speed}) {
    Color statusColor = status == 'Active' ? const Color(0xFF38FF9C) : const Color(0xFFFFB020);
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
          Text('Bat: $battery', style: const TextStyle(fontSize: 10, color: Color(0xFF7C8B85))),
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
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: currentLocation ?? defaultCenter, initialZoom: 16.0),
          children: [
            _tileLayer(),
            if (dronePath.length > 1) _pathLayer(),
            _droneMarker(),
            if (currentLocation != null) _currentLocationMarker(),
            _hazardousZonesLayer(),
          ],
        ),
      ),
    );
  }

  Widget _pathLayer() {
    return PolylineLayer(
      polylines: [
        Polyline(
          points: dronePath,
          strokeWidth: 3,
          color: const Color(0xFF38FF9C).withOpacity(0.6),
        ),
      ],
    );
  }

  Widget _droneMarker() {
    return MarkerLayer(
      markers: [
        Marker(
          point: dronePosition,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF38FF9C),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.air, color: Colors.black, size: 24),
          ),
        ),
      ],
    );
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

  Widget _hazardousZonesLayer() {
    return CircleLayer(
      circles: hazardousZones.map((zone) {
        Color zoneColor;
        switch (zone.severity) {
          case 'critical':
            zoneColor = const Color(0xFFFF4D4F);
            break;
          case 'high':
            zoneColor = const Color(0xFFFF7A45);
            break;
          case 'medium':
            zoneColor = const Color(0xFFFFB020);
            break;
          default:
            zoneColor = const Color(0xFF2F80ED);
        }
        return CircleMarker(
          point: zone.center,
          radius: zone.radiusKm * 1000, // Convert km to meters
          color: zoneColor.withOpacity(zone.detected ? 0.6 : 0.2),
          borderColor: zoneColor,
          borderStrokeWidth: 2,
        );
      }).toList(),
    );
  }

  Widget _tileLayer() {
    return TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c'], userAgentPackageName: 'com.example.cbrn4');
  }

  Widget _buildTelemetryPanel() {
    final List<SystemComponent> components = [
      SystemComponent(name: 'MINI BTS', value: 0.85, hasWarning: false),
      SystemComponent(name: 'RECON LINK', value: 0.92, hasWarning: false),
      SystemComponent(name: 'AI SYSTEMS', value: 0.78, hasWarning: true),
      SystemComponent(name: 'ENCRYPTION', value: 1.0, hasWarning: false),
      SystemComponent(name: 'UAV SWARM', value: 0.95, hasWarning: false),
      SystemComponent(name: 'UGV FLEET', value: 0.88, hasWarning: false),
    ];
    
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
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF38FF9C).withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Text('OPTIMAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF38FF9C)))),
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

class HazardousZone {
  final String name;
  final LatLng center;
  final double radiusKm;
  final String severity;
  final String substanceType;
  bool detected;

  HazardousZone({
    required this.name,
    required this.center,
    required this.radiusKm,
    required this.severity,
    required this.substanceType,
    this.detected = false,
  });
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
