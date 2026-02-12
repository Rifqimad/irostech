// lib/screens/live_map_screen.dart

import 'dart:async';
import '../services/firebase_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
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

  // Drone data
  final List<Drone> drones = [];


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
      // Initialize drones around user's location
      _initializeDrones(userLocation);
      // Move map to user's location
      mapController.move(userLocation, 16.0);
    });
  }

  void _initializeDrones(LatLng userLocation) {
    // Create 2 drones around the user's location
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

    drones.clear();
    drones.addAll([drone1, drone2]);
  }

  @override
  Widget build(BuildContext context) {
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
    return ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [
      FlutterMap(
        mapController: mapController,
        options: MapOptions(initialCenter: currentLocation ?? defaultCenter, initialZoom: 16.0),
        children: [
          _tileLayer(),
          if (currentLocation != null) _currentLocationMarker(),
          if (drones.isNotEmpty) _droneMarkers(),
        ],
      ),
      Positioned(top: 16, right: 16, child: _mapControls()),
      Positioned(bottom: 16, left: 16, child: _zoomButtons()),
    ]));
  }

  Widget _tileLayer() {
    return TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a', 'b', 'c'], userAgentPackageName: 'com.example.cbrn4');
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
      markers: drones.map((drone) {
        return Marker(
          point: drone.position,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Stack(
              children: [
                const Icon(Icons.flight, color: Colors.black, size: 24),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${drone.battery}%',
                      style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _zoomButtons() {
    return Container(decoration: BoxDecoration(color: const Color(0xFF101915).withOpacity(0.95), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1C2A24))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      IconButton(onPressed: () => mapController.move(mapController.camera.center, mapController.camera.zoom + 1), icon: const Icon(Icons.add, size: 20), padding: const EdgeInsets.all(8), style: IconButton.styleFrom(backgroundColor: const Color(0xFF1C2A24), foregroundColor: const Color(0xFFE6F4EE))),
      const SizedBox(height: 1),
      IconButton(onPressed: () => mapController.move(mapController.camera.center, mapController.camera.zoom - 1), icon: const Icon(Icons.remove, size: 20), padding: const EdgeInsets.all(8), style: IconButton.styleFrom(backgroundColor: const Color(0xFF1C2A24), foregroundColor: const Color(0xFFE6F4EE))),
    ]));
  }

  Widget _mapControls() {
    return Container(width: 160, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF101915).withOpacity(0.95), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1C2A24))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _mapToggle(label: 'Pan Mode', active: true, onTap: () {}),
      const SizedBox(height: 6),
      _mapToggle(label: 'Layer: ${layerType[0].toUpperCase()}${layerType.substring(1)}', active: layerType == 'standard', onTap: () => setState(() => layerType = layerType == 'standard' ? 'satellite' : 'standard')),
      const SizedBox(height: 6),
      _mapToggle(label: 'Trails: ${showTrails ? 'ON' : 'OFF'}', active: showTrails, onTap: () => setState(() => showTrails = !showTrails)),
      const SizedBox(height: 6),
      _mapToggle(label: 'Plume: ${plumeOn ? 'ON' : 'OFF'}', active: plumeOn, onTap: () => setState(() => plumeOn = !plumeOn)),
      const SizedBox(height: 6),
      _mapToggle(label: 'Heatmap: ${showHeatmap ? 'ON' : 'OFF'}', active: showHeatmap, onTap: () => setState(() => showHeatmap = !showHeatmap)),
      const SizedBox(height: 6),
      _mapToggle(label: 'Routes: ${showRoutes ? 'ON' : 'OFF'}', active: showRoutes, onTap: () => setState(() => showRoutes = !showRoutes)),
      const SizedBox(height: 6),
      _mapToggle(label: 'Geofences: ${showGeofences ? 'ON' : 'OFF'}', active: showGeofences, onTap: () => setState(() => showGeofences = !showGeofences)),
    ]));
  }

  Widget _mapToggle({required String label, required bool active, required VoidCallback onTap}) {
    return SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: active ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24), foregroundColor: active ? Colors.black : const Color(0xFFE6F4EE), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), minimumSize: const Size(0, 0)), child: Text(label, style: const TextStyle(fontSize: 11))));
  }

  Widget _buildRightPanel() {
    return SingleChildScrollView(child: Column(children: [
      _grid(columns: 2, children: [
        _panel(title: 'Active Alerts', child: Column(children: const [_SeverityRow(label: 'Critical', value: '02', severity: 'critical'), _SeverityRow(label: 'High', value: '04', severity: 'high'), _SeverityRow(label: 'Medium', value: '11', severity: 'medium'), _SeverityRow(label: 'Low', value: '23', severity: 'low')])),
      ]),
      const SizedBox(height: 16),
      _grid(columns: 2, children: [
        _panel(title: 'Incident Workflow', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButton<String>(value: incidentSeverity, dropdownColor: const Color(0xFF101915), isExpanded: true, items: const [DropdownMenuItem(value: 'critical', child: Text('Critical')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'medium', child: Text('Medium')), DropdownMenuItem(value: 'low', child: Text('Low'))], onChanged: (v) => setState(() => incidentSeverity = v ?? 'critical')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => setState(() => incidentMode = !incidentMode), style: ElevatedButton.styleFrom(backgroundColor: incidentMode ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24), foregroundColor: Colors.black), child: Text(incidentMode ? 'Add: ON' : 'Add Incident')),
        ])),
        _panel(title: 'Alert Timeline', child: Column(children: [
          DropdownButton<String>(value: timelineFilter, dropdownColor: const Color(0xFF101915), isExpanded: true, items: const [DropdownMenuItem(value: 'all', child: Text('All')), DropdownMenuItem(value: 'critical', child: Text('Critical')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'medium', child: Text('Medium')), DropdownMenuItem(value: 'low', child: Text('Low'))], onChanged: (v) => setState(() => timelineFilter = v ?? 'all')),
          const SizedBox(height: 8),
          ..._filteredAlerts().map((a) => _TimelineRow(alert: a)),
        ])),
        _panel(title: 'Notification Center', child: Column(children: [
          Row(children: [ElevatedButton(onPressed: () => setState(() => notificationSoundOn = !notificationSoundOn), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: Text('Sound: ${notificationSoundOn ? 'On' : 'Off'}')), const SizedBox(width: 8), ElevatedButton(onPressed: _handleTestAlert, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: const Text('Test'))]),
          const SizedBox(height: 8),
          ...notifications.take(3).map((n) => _TimelineRow(notification: n)),
        ])),
      ]),
      const SizedBox(height: 16),
      _panel(title: 'Data Export', child: Row(children: [ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: const Text('JSON')), const SizedBox(width: 8), ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: const Text('CSV'))])),
    ]));
  }


  List<AlertItem> _filteredAlerts() {
    if (timelineFilter == 'all') return alertTimelineData;
    return alertTimelineData.where((a) => a.severity == timelineFilter).toList();
  }

  void _handleTestAlert() {
    final now = DateTime.now();
    setState(() => notifications.insert(0, NotificationItem(id: now.millisecond, message: 'Test alert', time: '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}')));
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return LayoutBuilder(builder: (c, constr) {
      final w = constr.maxWidth;
      final adj = w < 800 ? 1 : w < 1200 ? (columns > 2 ? 2 : columns) : columns;
      return Wrap(spacing: 16, runSpacing: 16, children: children.map((child) => SizedBox(width: (w - (16 * (adj - 1))) / adj, child: child)).toList());
    });
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF101915), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1C2A24))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10), child]));
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
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _c(), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
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
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: clr, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(txt, style: const TextStyle(fontSize: 11))),
        Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF7C8B85))),
      ]),
    );
  }
}
