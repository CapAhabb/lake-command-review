import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

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
  final MapController _mapController = MapController();
  List<Polygon> _shorelinePolygons = const [];
  vtr.Theme? _noaaBathymetryTheme;
  final vmt.TileProviders _noaaBathymetryProviders = vmt.TileProviders({
    'esri': vmt.NetworkVectorTileProvider(
      urlTemplate:
          'https://tiles.arcgis.com/tiles/C8EMgrsFcRFL6LrL/arcgis/rest/services/csb_vector_tiles/VectorTileServer/tile/{z}/{y}/{x}.pbf',
      minimumZoom: 0,
      maximumZoom: 19,
    ),
  });

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

  double _plotterZoom = 7.0;

  // Fake GPS data (will be replaced with real)
  String _gpsStatus = "3D Fix";
  String _time = "2:34 PM";
  double _speed = 2.8;
  final double _depth = 47.0;
  final double _waterTemp = 68.4;

  LatLng _currentPosition = const LatLng(43.4, -86.7);

  @override
  void initState() {
    super.initState();
    _loadShorelinePolygons();
    _loadNoaaBathymetryStyle();
    _updateRealTimeData();
  }

  Future<void> _loadNoaaBathymetryStyle() async {
    final source = await rootBundle.loadString(
      'assets/noaa_crowdsourced_bathymetry_style.json',
    );
    final style = jsonDecode(source) as Map<String, dynamic>;
    final theme = vtr.ThemeReader().read(style);

    if (!mounted) return;
    setState(() => _noaaBathymetryTheme = theme);
  }

  Future<void> _loadShorelinePolygons() async {
    final source = await rootBundle.loadString(
      'assets/lake_michigan_shoreline.geojson',
    );
    final geoJson = jsonDecode(source) as Map<String, dynamic>;
    final features = geoJson['features'] as List<dynamic>;
    final polygons = <Polygon>[];

    for (final feature in features.cast<Map<String, dynamic>>()) {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;

      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final polygonCoordinates = type == 'Polygon'
          ? <dynamic>[coordinates]
          : type == 'MultiPolygon'
          ? coordinates
          : const <dynamic>[];

      for (final polygon in polygonCoordinates) {
        final rings = (polygon as List<dynamic>)
            .map(
              (ring) => (ring as List<dynamic>).map((point) {
                final coordinate = point as List<dynamic>;
                return LatLng(
                  (coordinate[1] as num).toDouble(),
                  (coordinate[0] as num).toDouble(),
                );
              }).toList(),
            )
            .toList();

        if (rings.isEmpty) continue;
        polygons.add(
          Polygon(
            points: rings.first,
            holePointsList: rings.length > 1 ? rings.sublist(1) : null,
            color: const Color(0x3329B6F6),
            borderColor: const Color(0xFF29B6F6),
            borderStrokeWidth: 2,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _shorelinePolygons = polygons);
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

  void _updateOpacity(String module, double delta) {
    setState(() {
      final currentOpacity = _moduleOpacity[module] ?? 1.0;
      _moduleOpacity[module] = (currentOpacity - delta * 0.01).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050607),
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1168,
              height: 760,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 18, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B0D),
                  border: Border.all(color: const Color(0xFF4A4F53), width: 4),
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 58,
                      child: Center(
                        child: Text(
                          'LakeGuard Pro',
                          style: TextStyle(
                            color: Color(0xFFB9BDC1),
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildLakeGuardDisplay()),
                          const SizedBox(width: 14),
                          SizedBox(width: 104, child: _buildHardwareRail()),
                        ],
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

  Widget _buildLakeGuardDisplay() {
    return Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF07111B), Color(0xFF003B64), Color(0xFF07111B)],
            ),
          ),
          child: const Row(
            children: [
              Text(
                'AquaPlotter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 18),
              Icon(Icons.signal_cellular_alt, color: Colors.white, size: 27),
              Spacer(),
              Icon(Icons.navigation, color: Colors.white, size: 32),
              Spacer(),
              Icon(Icons.usb, color: Color(0xFF15F04B), size: 23),
              SizedBox(width: 18),
              Icon(Icons.battery_full, color: Color(0xFF55F15B), size: 30),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildChartArea()),
              SizedBox(width: 142, child: _buildTelemetryRail()),
            ],
          ),
        ),
        SizedBox(height: 154, child: _buildModuleStrip()),
      ],
    );
  }

  Widget _buildChartArea() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(44.0, -87.0),
            initialZoom: _plotterZoom,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) setState(() => _plotterZoom = position.zoom);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.starter_app',
            ),
            PolygonLayer(polygons: _shorelinePolygons),
            if (_noaaBathymetryTheme case final theme?)
              vmt.VectorTileLayer(
                theme: theme,
                tileProviders: _noaaBathymetryProviders,
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition,
                  child: const Icon(
                    Icons.directions_boat,
                    color: Color(0xFF17272B),
                    size: 38,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_moduleStates['Species Density'] ?? false)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: _moduleOpacity['Species Density']!,
                child: Container(color: const Color(0x332400FF)),
              ),
            ),
          ),
        const Positioned(
          left: 10,
          bottom: 10,
          child: _MapSquareButton(icon: Icons.home),
        ),
        const Positioned(
          right: 10,
          top: 10,
          child: _MapSquareButton(icon: Icons.gps_fixed),
        ),
      ],
    );
  }

  Widget _buildTelemetryRail() {
    return Container(
      color: const Color(0xFF07090A),
      child: Column(
        children: [
          _buildTelemetryCard(
            'Depth:',
            _depth.toStringAsFixed(0),
            suffix: 'ft',
            flex: 6,
          ),
          _buildTelemetryCard(
            'Water Temp:',
            _waterTemp.toStringAsFixed(1),
            suffix: '°F',
            flex: 5,
          ),
          _buildTelemetryCard(
            'Speed:',
            _speed.toStringAsFixed(1),
            suffix: 'mph',
            flex: 5,
          ),
          _buildTelemetryCard('Time', _time, flex: 4),
          _buildTelemetryCard('GPS', _gpsStatus, flex: 4),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(
    String label,
    String value, {
    String? suffix,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF51565A), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  text: value,
                  children: [
                    if (suffix != null)
                      TextSpan(
                        text: suffix,
                        style: const TextStyle(fontSize: 18),
                      ),
                  ],
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleStrip() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _moduleStates.keys
          .map((module) => Expanded(child: _buildModuleControl(module)))
          .toList(),
    );
  }

  Widget _buildModuleControl(String module) {
    final isOn = _moduleStates[module] ?? false;
    final opacity = _moduleOpacity[module] ?? 1;
    return GestureDetector(
      onTap: () => _toggleModule(module),
      onVerticalDragUpdate: (details) =>
          _updateOpacity(module, details.delta.dy),
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: isOn && module == 'Species Density'
              ? const Color(0xFF12DB16)
              : const Color(0xFF111416),
          border: Border.all(color: const Color(0xFF555A5E)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    module.replaceAll(' / ', ' /\n').replaceAll(' @ ', ' @\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 0.95,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CustomPaint(
                      painter: _OrangeKnobPainter(value: opacity, active: isOn),
                    ),
                  ),
                  Text(
                    '${(opacity * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 30,
              width: double.infinity,
              alignment: Alignment.center,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
              color: const Color(0xFF1A1C1E),
              child: Text(
                isOn ? 'AUTO' : 'OFF',
                style: const TextStyle(
                  color: Color(0xFFFF9A36),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareRail() {
    return Column(
      children: [
        _buildRoundHardwareButton(Icons.arrow_drop_up),
        const SizedBox(height: 12),
        _buildRoundHardwareButton(Icons.add, onTap: () => _zoomBy(1)),
        const SizedBox(height: 12),
        _buildRoundHardwareButton(Icons.remove, onTap: () => _zoomBy(-1)),
        const SizedBox(height: 18),
        SizedBox(width: 88, height: 88, child: _buildBlueKnob()),
        const Spacer(),
        Container(
          width: 84,
          height: 112,
          decoration: BoxDecoration(
            color: const Color(0xFF111315),
            border: Border.all(color: const Color(0xFF292D30), width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.arrow_drop_up, color: Color(0xFF6B6E71), size: 38),
              Icon(Icons.arrow_drop_up, color: Colors.red, size: 30),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 92,
          height: 68,
          child: OutlinedButton(
            onPressed: _showMenu,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF7043),
              side: const BorderSide(color: Color(0xFFFF6A28), width: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'MENU',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundHardwareButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111315),
          border: Border.all(color: const Color(0xFF292D30), width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF85898C), size: 38),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyLayout(BuildContext context) {
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
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    // Header
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "AquaPlotter",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Icon(
                            Icons.signal_cellular_4_bar,
                            color: Colors.white,
                          ),
                          const Text(
                            "Lake Intelligence Pro",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Icon(Icons.battery_full, color: Colors.green),
                        ],
                      ),
                    ),

                    // Map Area
                    Expanded(
                      child: CustomPaint(
                        painter: const _DeviceBezelPainter(),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final height = constraints.maxHeight;
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      width * 0.07,
                                      height * 0.08,
                                      width * 0.17,
                                      height * 0.10,
                                    ),
                                    child: Stack(
                                      children: [
                                        FlutterMap(
                                          mapController: _mapController,
                                          options: MapOptions(
                                            initialCenter: _currentPosition,
                                            initialZoom: _plotterZoom,
                                            onPositionChanged:
                                                (position, hasGesture) {
                                                  if (hasGesture) {
                                                    setState(
                                                      () => _plotterZoom =
                                                          position.zoom,
                                                    );
                                                  }
                                                },
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate:
                                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              userAgentPackageName:
                                                  'com.example.starter_app',
                                              // Replace with Navionics/Garmin tiles when ready
                                            ),
                                            PolygonLayer(
                                              polygons: _shorelinePolygons,
                                            ),
                                            if (_noaaBathymetryTheme
                                                case final theme?)
                                              vmt.VectorTileLayer(
                                                theme: theme,
                                                tileProviders:
                                                    _noaaBathymetryProviders,
                                              ),
                                            // Boat marker
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: _currentPosition,
                                                  child: const Icon(
                                                    Icons.directions_boat,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Overlay data (opacity controlled by dials)
                                        if (_moduleStates['Species Density'] ??
                                            false)
                                          Positioned.fill(
                                            child: Opacity(
                                              opacity:
                                                  _moduleOpacity['Species Density']!,
                                              child: Container(
                                                color: Colors.purple.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Add more layers for other modules...

                                        // Right Panel Readings (White as requested)
                                        Positioned(
                                          right: 12,
                                          top: 12,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              _buildReading(
                                                "Depth:",
                                                "${_depth.toStringAsFixed(0)} ft",
                                              ),
                                              _buildReading(
                                                "Water Temp:",
                                                "${_waterTemp.toStringAsFixed(1)}°F",
                                              ),
                                              _buildReading(
                                                "Speed:",
                                                "${_speed.toStringAsFixed(1)} mph",
                                              ),
                                              _buildReading("Time:", _time),
                                              _buildReading("GPS:", _gpsStatus),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: width * 0.875,
                                  top: height * 0.045,
                                  width: width * 0.035,
                                  height: width * 0.035,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF080808),
                                      border: Border.all(
                                        color: const Color(0xFF73787B),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: width * 0.845,
                                  top: height * 0.13,
                                  width: width * 0.10,
                                  height: width * 0.10,
                                  child: _buildBlueKnob(),
                                ),
                                Positioned(
                                  left: width * 0.84,
                                  top: height * 0.35,
                                  width: width * 0.11,
                                  height: height * 0.38,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: _buildBezelButton(
                                          icon: Icons.add,
                                          label: 'ZOOM IN',
                                          onPressed: () => _zoomBy(1),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Expanded(
                                        child: _buildBezelButton(
                                          icon: Icons.remove,
                                          label: 'ZOOM OUT',
                                          onPressed: () => _zoomBy(-1),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Expanded(
                                        flex: 2,
                                        child: _buildBezelButton(
                                          icon: Icons.menu,
                                          label: 'MENU',
                                          onPressed: _showMenu,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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
                            onVerticalDragUpdate: (details) =>
                                _updateOpacity(module, details.delta.dy),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: CustomPaint(
                                    painter: _OrangeKnobPainter(
                                      value: _moduleOpacity[module] ?? 1.0,
                                      active: isOn,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  module,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  isOn
                                      ? "ON • ${((_moduleOpacity[module] ?? 1.0) * 100).round()}%"
                                      : "OFF",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isOn ? Colors.green : Colors.grey,
                                  ),
                                ),
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
          ],
        ),
      ),
    );
  }

  void _zoomBy(double amount) {
    setState(() {
      _plotterZoom = (_plotterZoom + amount).clamp(5.0, 20.0);
    });
    _mapController.move(_mapController.camera.center, _plotterZoom);
  }

  void _showMenu() {
    showModalBottomSheet(context: context, builder: (_) => const MenuPanel());
  }

  Widget _buildBlueKnob() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _plotterZoom += details.delta.dy * -0.05;
          _plotterZoom = _plotterZoom.clamp(5.0, 20.0);
        });
        _mapController.move(_mapController.camera.center, _plotterZoom);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF09151B),
          border: Border.all(color: Colors.cyan, width: 5),
          boxShadow: const [BoxShadow(color: Colors.cyan, blurRadius: 18)],
        ),
        child: const Center(child: Icon(Icons.zoom_in, color: Colors.cyan)),
      ),
    );
  }

  Widget _buildBezelButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox.expand(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.orange,
          shape: const RoundedRectangleBorder(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReading(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "$label $value",
        style: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MapSquareButton extends StatelessWidget {
  const _MapSquareButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xDD0B0D0E),
        border: Border.all(color: const Color(0xFF777C80)),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _DeviceBezelPainter extends CustomPainter {
  const _DeviceBezelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(size.width * 0.025, size.height * 0.05)
      ..lineTo(size.width * 0.09, 0)
      ..lineTo(size.width * 0.80, 0)
      ..lineTo(size.width * 0.84, size.height * 0.035)
      ..lineTo(size.width * 0.96, size.height * 0.055)
      ..lineTo(size.width, size.height * 0.20)
      ..lineTo(size.width, size.height * 0.82)
      ..lineTo(size.width * 0.96, size.height * 0.96)
      ..lineTo(size.width * 0.84, size.height)
      ..lineTo(size.width * 0.80, size.height * 0.97)
      ..lineTo(size.width * 0.08, size.height)
      ..lineTo(size.width * 0.025, size.height * 0.93)
      ..lineTo(0, size.height * 0.78)
      ..lineTo(0, size.height * 0.18)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C6062), Color(0xFF26292B), Color(0xFF4A4E50)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF777C7F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.06),
      Offset(size.width * 0.82, size.height * 0.93),
      Paint()
        ..color = const Color(0xFF111315)
        ..strokeWidth = 2,
    );

    final ventPaint = Paint()
      ..color = const Color(0xFF17191A)
      ..strokeWidth = 1;
    for (var index = 0; index < 8; index++) {
      final y = size.height * (0.80 + index * 0.012);
      canvas.drawLine(
        Offset(size.width * 0.88, y),
        Offset(size.width * 0.94, y),
        ventPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DeviceBezelPainter oldDelegate) => false;
}

class _OrangeKnobPainter extends CustomPainter {
  const _OrangeKnobPainter({required this.value, required this.active});

  final double value;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;

    if (active) {
      canvas.drawCircle(
        center,
        radius + 3,
        Paint()
          ..color = const Color(0x77FF6A00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFF2D2D2D), Color(0xFF090909), Color(0xFF000000)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = active ? const Color(0xFFFF8A1A) : const Color(0xFF5A3B17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final angle = -math.pi * 0.75 + value * math.pi * 1.5;
    final end = Offset(
      center.dx + (radius - 12) * math.cos(angle),
      center.dy + (radius - 12) * math.sin(angle),
    );
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = active ? const Color(0xFFFFD28C) : const Color(0xFF8A6A40)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF050505));
  }

  @override
  bool shouldRepaint(covariant _OrangeKnobPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.active != active;
}

class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Text(
            "Advanced Menu - Settings / API Config / Data Layers",
            style: TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
