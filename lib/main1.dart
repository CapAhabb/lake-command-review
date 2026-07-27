import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const LakeIntelligenceProApp());
}

class LakeIntelligenceProApp extends StatelessWidget {
  const LakeIntelligenceProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lake Intelligence Pro',
      theme: ThemeData.dark(),
      home: const LakeGuardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LakeGuardScreen extends StatefulWidget {
  const LakeGuardScreen({super.key});

  @override
  State<LakeGuardScreen> createState() => _LakeGuardScreenState();
}

class _LakeGuardScreenState extends State<LakeGuardScreen> {
  // Module states
  final Map<String, bool> _moduleStates = {
    'Species Density': true,
    'Bait Density': true,
    'Current': true,
    'Current @ Depth': false,
    'Surface Temp': true,
    'Thermocline': true,
    'Waypoints / Marked Fish': true,
    'Weather Radar': false,
  };

  final Map<String, double> _moduleOpacity = {
    'Species Density': 1.0,
    'Bait Density': 0.85,
    'Current': 0.7,
    'Current @ Depth': 0.6,
    'Surface Temp': 0.9,
    'Thermocline': 0.75,
    'Waypoints / Marked Fish': 0.95,
    'Weather Radar': 0.5,
  };

  double _plotterZoom = 15.0;

  // Fake GPS data (will be replaced with real)
  String _gpsStatus = "3D Fix";
  String _time = "2:34 PM";
  double _speed = 2.8;
  final double _depth = 47.0;
  final double _waterTemp = 68.4;

  LatLng _currentPosition = const LatLng(44.5, -88.0); // Example lake coords

  @override
  void initState() {
    super.initState();
    _updateRealTimeData();
  }

  void _updateRealTimeData() async {
    // Time
    setState(() {
      _time = TimeOfDay.now().format(context);
    });

    // GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _speed = position.speed * 2.23694; // m/s → mph
        _gpsStatus = "3D Fix";
      });
    }
  }

  void _toggleModule(String module) {
    setState(() {
      _moduleStates[module] = !(_moduleStates[module] ?? false);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Screen Bezel
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700, width: 18),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 30),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    // Header
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("AquaPlotter", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Icon(Icons.signal_cellular_4_bar, color: Colors.white),
                          const Text("Lake Intelligence Pro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                          const Icon(Icons.battery_full, color: Colors.green),
                        ],
                      ),
                    ),

                    // Map Area
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: _currentPosition,
                              initialZoom: _plotterZoom,
                              onPositionChanged: (position, hasGesture) {
                                if (hasGesture) {
                                  setState(() => _plotterZoom = position.zoom);
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                // Replace with Navionics/Garmin tiles when ready
                              ),
                              // Boat marker
                              MarkerLayer(markers: [
                                Marker(
                                  point: _currentPosition,
                                  child: const Icon(Icons.directions_boat, color: Colors.white, size: 32),
                                ),
                              ]),
                            ],
                          ),

                          // Overlay data (opacity controlled by dials)
                          if (_moduleStates['Species Density'] ?? false)
                            Positioned.fill(child: Opacity(opacity: _moduleOpacity['Species Density']!, child: Container(color: Colors.purple.withValues(alpha: 0.2)))),
                          // Add more layers for other modules...

                          // Right Panel Readings (White as requested)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildReading("Depth:", "${_depth.toStringAsFixed(0)} ft"),
                                _buildReading("Water Temp:", "${_waterTemp.toStringAsFixed(1)}°F"),
                                _buildReading("Speed:", "${_speed.toStringAsFixed(1)} mph"),
                                _buildReading("Time:", _time),
                                _buildReading("GPS:", _gpsStatus),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Controls
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _moduleStates.keys.map((module) {
                          bool isOn = _moduleStates[module] ?? false;
                          return GestureDetector(
                            onTap: () => _toggleModule(module),
                            child: Column(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.orange, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isOn ? Colors.orange.withValues(alpha: 0.9) : Colors.orange.withValues(alpha: 0.3),
                                        blurRadius: isOn ? 20 : 8,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      module.split(' ').map((w) => w[0]).join(''),
                                      style: TextStyle(color: isOn ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(module, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                Text(isOn ? "ON" : "OFF", style: TextStyle(fontSize: 10, color: isOn ? Colors.green : Colors.grey)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Blue Dial (Plotter Control) - Bottom Right
            Positioned(
              bottom: 40,
              right: 40,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _plotterZoom += details.delta.dy * -0.05;
                    _plotterZoom = _plotterZoom.clamp(10.0, 20.0);
                  });
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyan, width: 8),
                    boxShadow: const [BoxShadow(color: Colors.cyan, blurRadius: 30)],
                  ),
                  child: const Center(child: Icon(Icons.zoom_in, size: 40, color: Colors.cyan)),
                ),
              ),
            ),

            // MENU Button
            Positioned(
              bottom: 60,
              right: 160,
              child: ElevatedButton(
                onPressed: () {
                  // Open separate menu
                  showModalBottomSheet(context: context, builder: (_) => const MenuPanel());
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("MENU", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReading(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: Text("$label $value", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }
}

class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [Text("Advanced Menu - Settings / API Config / Data Layers", style: TextStyle(fontSize: 20))],
      ),
    );
  }
}