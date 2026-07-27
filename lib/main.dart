import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'services/seagull_current_service.dart';

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

class _LakeGuardScreenState extends State<LakeGuardScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SeagullCurrentService _seagullCurrentService = SeagullCurrentService();
  List<Polygon> _shorelinePolygons = const [];
  List<Polyline> _bathymetryContours = const [];
  List<_CurrentParticle> _currentParticles = const [];
  List<_ParticleMaskArea> _currentMaskAreas = const [];
  List<_CurrentVector> _currentVectors = const [];
  List<SeagullScalarObservation> _waveObservations = const [];
  List<SeagullScalarObservation> _windObservations = const [];
  List<SeagullScalarObservation> _surfaceTemperatureObservations = const [];
  SeagullForecast? _seagullForecast;
  _CurrentMode _currentMode = _CurrentMode.surface;
  bool _forecastWaves = false;
  bool _forecastWind = false;
  bool _noaaLayersEnabled = false;
  bool _alternativeBezel = false;
  Color _userAccentColor = const Color(0xFFFF8A1A);
  final bool _membershipActive = false;
  int _seagullRequestId = 0;
  String _currentSourceLabel = 'SEAGULL • CONNECTING';
  vtr.Theme? _noaaBathymetryTheme;
  late final Timer _radarRefreshTimer;
  late final AnimationController _currentAnimationController;
  int _radarRefreshKey = DateTime.now().millisecondsSinceEpoch;
  bool _animateCurrents = true;
  String? _middleMouseModule;
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
    'Wind Speed': true,
    'Surface Temp': true,
    'Wave Height': true,
    'Waypoints / Marked Fish': true,
    'Weather Radar': false,
  };

  final Map<String, double> _moduleOpacity = {
    'Species Density': 1.0,
    'Bait Density': 0.85,
    'Current': 0.9,
    'Wind Speed': 0.8,
    'Surface Temp': 0.9,
    'Wave Height': 0.85,
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
    _currentAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadShorelinePolygons();
    _loadBathymetryContours();
    _loadNoaaBathymetryStyle();
    _loadSeagullData();
    _updateRealTimeData();
    _radarRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      setState(() => _radarRefreshKey = DateTime.now().millisecondsSinceEpoch);
      _loadSeagullData();
    });
  }

  @override
  void dispose() {
    _radarRefreshTimer.cancel();
    _currentAnimationController.dispose();
    _seagullCurrentService.close();
    super.dispose();
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

  Future<void> _loadBathymetryContours() async {
    final source = await rootBundle.loadString(
      'assets/noaa_lake_michigan_bathymetry_contours.geojson',
    );
    final geoJson = jsonDecode(source) as Map<String, dynamic>;
    final features = geoJson['features'] as List<dynamic>;
    final contours = <Polyline>[];

    for (final feature in features.cast<Map<String, dynamic>>()) {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;

      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final lines = type == 'LineString'
          ? <dynamic>[coordinates]
          : type == 'MultiLineString'
          ? coordinates
          : const <dynamic>[];
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final depth = (properties['depth'] as num?)?.toDouble() ?? 0;
      final isMajorContour = depth.remainder(50).abs() < 0.01;

      for (final line in lines) {
        final points = (line as List<dynamic>).map((point) {
          final coordinate = point as List<dynamic>;
          return LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          );
        }).toList();
        if (points.length < 2) continue;

        contours.add(
          Polyline(
            points: points,
            strokeWidth: isMajorContour ? 1.35 : 0.7,
            color: isMajorContour
                ? const Color(0xCC183A4D)
                : const Color(0x7A294D5E),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _bathymetryContours = contours);
  }

  Future<void> _loadShorelinePolygons() async {
    final source = await rootBundle.loadString(
      'assets/lake_michigan_shoreline.geojson',
    );
    final geoJson = jsonDecode(source) as Map<String, dynamic>;
    final features = geoJson['features'] as List<dynamic>;
    final polygons = <Polygon>[];
    final currentMaskAreas = <List<List<LatLng>>>[];

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
        currentMaskAreas.add(rings);
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
    final maskAreas = currentMaskAreas.map(_ParticleMaskArea.new).toList();
    setState(() {
      _shorelinePolygons = polygons;
      _currentMaskAreas = maskAreas;
      _currentParticles = _buildCurrentParticles(maskAreas, _currentVectors);
    });
  }

  Future<void> _loadSeagullData() async {
    final requestId = ++_seagullRequestId;
    final requestedCurrentMode = _currentMode;
    final requestedForecastWaves = _forecastWaves;
    final requestedForecastWind = _forecastWind;
    if (mounted) {
      setState(() => _currentSourceLabel = 'SEAGULL • CONNECTING');
    }
    final currentFuture = requestedCurrentMode == _CurrentMode.forecast
        ? Future.value(<SeagullCurrentObservation>[])
        : _seagullCurrentService.fetchLatestLakeMichigan(
            targetDepthMeters: requestedCurrentMode == _CurrentMode.atDepth
                ? 9
                : 3,
          );
    final waveFuture = requestedForecastWaves
        ? Future.value(<SeagullScalarObservation>[])
        : _seagullCurrentService.fetchLatestWaveHeights();
    final windFuture = requestedForecastWind
        ? Future.value(<SeagullScalarObservation>[])
        : _seagullCurrentService.fetchLatestWindSpeeds();
    final temperatureFuture = _seagullCurrentService
        .fetchLatestSurfaceTemperatures();
    final forecastFuture =
        requestedCurrentMode == _CurrentMode.forecast ||
            requestedForecastWaves ||
            requestedForecastWind
        ? _seagullCurrentService.fetchForecast(
            latitude: _currentPosition.latitude,
            longitude: _currentPosition.longitude,
          )
        : Future.value(null);

    final observations = await currentFuture;
    final waves = await waveFuture;
    final winds = await windFuture;
    final temperatures = await temperatureFuture;
    final forecast = await forecastFuture;
    if (!mounted || requestId != _seagullRequestId) return;

    var vectors = observations
        .map(
          (observation) => _CurrentVector(
            observation.latitude,
            observation.longitude,
            observation.directionRadians,
            observation.speedMetersPerSecond.clamp(0.01, 1.0),
          ),
        )
        .toList();
    if (requestedCurrentMode == _CurrentMode.forecast &&
        forecast?.currentSpeedMetersPerSecond != null &&
        forecast?.currentDirectionDegrees != null) {
      vectors = [
        _CurrentVector(
          _currentPosition.latitude,
          _currentPosition.longitude,
          math.pi / 2 - forecast!.currentDirectionDegrees! * math.pi / 180,
          forecast.currentSpeedMetersPerSecond!.clamp(0.01, 1),
        ),
      ];
    }

    final hasAnyLiveData =
        observations.isNotEmpty ||
        waves.isNotEmpty ||
        winds.isNotEmpty ||
        temperatures.isNotEmpty ||
        forecast != null;
    String currentLabel;
    if (vectors.isEmpty) {
      currentLabel = hasAnyLiveData
          ? 'SEAGULL • ${requestedCurrentMode.label} CURRENT UNAVAILABLE • TAP TO RETRY'
          : 'SEAGULL • LIVE CONNECTION FAILED • TAP TO RETRY';
    } else if (requestedCurrentMode == _CurrentMode.forecast) {
      currentLabel = 'SEAGULL • CURRENT FORECAST';
    } else {
      final newest = observations
          .map((observation) => observation.observedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final age = DateTime.now().toUtc().difference(newest.toUtc());
      final freshness = age.inHours < 1
          ? '<1H'
          : age.inHours < 48
          ? '${age.inHours}H'
          : '${age.inDays}D';
      currentLabel =
          'SEAGULL • ${vectors.length} ADCP • ${requestedCurrentMode.label} • $freshness';
    }

    setState(() {
      _currentVectors = vectors;
      _waveObservations = waves;
      _windObservations = winds;
      _surfaceTemperatureObservations = temperatures;
      _seagullForecast = forecast;
      _currentParticles = _buildCurrentParticles(_currentMaskAreas, vectors);
      _currentSourceLabel = currentLabel;
    });
  }

  void _cycleModuleMode(String module) {
    setState(() {
      switch (module) {
        case 'Current':
          _currentMode = _currentMode.next;
        case 'Wind Speed':
          _forecastWind = !_forecastWind;
        case 'Wave Height':
          _forecastWaves = !_forecastWaves;
      }
    });
    _loadSeagullData();
  }

  String _moduleModeLabel(String module) {
    return switch (module) {
      'Current' => _currentMode.label,
      'Wind Speed' => _forecastWind ? 'FORECAST' : 'OBSERVED',
      'Wave Height' => _forecastWaves ? 'FORECAST' : 'OBSERVED',
      _ => (_moduleStates[module] ?? false) ? 'ON' : 'OFF',
    };
  }

  List<Marker> _buildWaveMarkers() {
    if (_forecastWaves) {
      final value = _seagullForecast?.waveHeightMeters;
      if (value == null) return const [];
      return [
        Marker(
          point: _currentPosition,
          width: 92,
          height: 44,
          child: _EnvironmentalDataMarker(
            icon: Icons.waves,
            value: '${(value * 3.28084).toStringAsFixed(1)} ft',
            mode: 'SEAGULL FCST',
            color: const Color(0xFF50D7FF),
          ),
        ),
      ];
    }
    return _waveObservations
        .map(
          (observation) => Marker(
            point: LatLng(observation.latitude, observation.longitude),
            width: 92,
            height: 44,
            child: _EnvironmentalDataMarker(
              icon: Icons.waves,
              value: '${(observation.value * 3.28084).toStringAsFixed(1)} ft',
              mode: 'SEAGULL OBS',
              color: const Color(0xFF50D7FF),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildWindMarkers() {
    if (_forecastWind) {
      final value = _seagullForecast?.windSpeedMetersPerSecond;
      if (value == null) return const [];
      return [
        Marker(
          point: _currentPosition,
          width: 92,
          height: 44,
          child: _EnvironmentalDataMarker(
            icon: Icons.air,
            value: '${(value * 2.23694).toStringAsFixed(1)} mph',
            mode: 'SEAGULL FCST',
            color: const Color(0xFFFFC85A),
          ),
        ),
      ];
    }
    return _windObservations
        .map(
          (observation) => Marker(
            point: LatLng(observation.latitude, observation.longitude),
            width: 92,
            height: 44,
            child: _EnvironmentalDataMarker(
              icon: Icons.air,
              value: '${(observation.value * 2.23694).toStringAsFixed(1)} mph',
              mode: 'SEAGULL OBS',
              color: const Color(0xFFFFC85A),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildSurfaceTemperatureMarkers() {
    return _surfaceTemperatureObservations
        .map(
          (observation) => Marker(
            point: LatLng(observation.latitude, observation.longitude),
            width: 92,
            height: 44,
            child: _EnvironmentalDataMarker(
              icon: Icons.thermostat,
              value:
                  '${((observation.value - 273.15) * 9 / 5 + 32).toStringAsFixed(1)} °F',
              mode: 'SEAGULL OBS',
              color: const Color(0xFFFF795A),
            ),
          ),
        )
        .toList();
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
    if (module == 'Current') {
      _syncCurrentAnimation();
    }
  }

  void _updateOpacity(String module, double delta) {
    setState(() {
      final currentOpacity = _moduleOpacity[module] ?? 1.0;
      _moduleOpacity[module] = (currentOpacity - delta * 0.01).clamp(0.0, 1.0);
    });
  }

  void _setCurrentAnimation(bool enabled) {
    setState(() => _animateCurrents = enabled);
    _syncCurrentAnimation();
  }

  void _syncCurrentAnimation() {
    if (_animateCurrents && (_moduleStates['Current'] ?? false)) {
      _currentAnimationController.repeat();
    } else {
      _currentAnimationController.stop();
    }
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
                padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.85, -1),
                    end: Alignment(0.75, 1),
                    colors: _alternativeBezel
                        ? const [
                            Color(0xFF263A48),
                            Color(0xFF14242E),
                            Color(0xFF081117),
                            Color(0xFF030709),
                            Color(0xFF122833),
                          ]
                        : const [
                            Color(0xFF646A6E),
                            Color(0xFF303438),
                            Color(0xFF121517),
                            Color(0xFF07090A),
                            Color(0xFF292D30),
                          ],
                    stops: const [0, 0.10, 0.42, 0.76, 1],
                  ),
                  border: Border.all(
                    color: _alternativeBezel
                        ? _userAccentColor
                        : const Color(0xFF777D81),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF000000),
                      blurRadius: 34,
                      spreadRadius: 4,
                      offset: Offset(0, 18),
                    ),
                    BoxShadow(
                      color: Color(0x887D8790),
                      blurRadius: 5,
                      offset: Offset(-2, -3),
                    ),
                  ],
                ),
                foregroundDecoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x32FFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x00000000),
                      Color(0x52000000),
                    ],
                    stops: [0, 0.16, 0.68, 1],
                  ),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: const Color(0x66000000), width: 7),
                ),
                child: CustomPaint(
                  painter: const _PlasticTexturePainter(),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 58,
                        child: Center(
                          child: Text(
                            'LakeGuard Pro',
                            style: TextStyle(
                              color: _alternativeBezel
                                  ? _userAccentColor
                                  : const Color(0xFFB9BDC1),
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1.2,
                              shadows: [
                                Shadow(
                                  color: Color(0xCC000000),
                                  blurRadius: 3,
                                  offset: Offset(2, 3),
                                ),
                                Shadow(
                                  color: Color(0x557E8990),
                                  offset: Offset(-1, -1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF080A0C),
                                      Color(0xFF3F4549),
                                      Color(0xFF0A0C0E),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black,
                                      blurRadius: 12,
                                      spreadRadius: 4,
                                      offset: Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Color(0x557E878D),
                                      blurRadius: 2,
                                      offset: Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: _buildLakeGuardDisplay(),
                                ),
                              ),
                            ),
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
        SizedBox(height: 126, child: _buildModuleStrip()),
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
            if (_moduleStates['Surface Temp'] ?? false)
              Opacity(
                opacity: _moduleOpacity['Surface Temp'] ?? 0.9,
                child: MarkerLayer(markers: _buildSurfaceTemperatureMarkers()),
              ),
            PolylineLayer(polylines: _bathymetryContours),
            PolygonLayer(polygons: _shorelinePolygons),
            if (_noaaBathymetryTheme != null)
              vmt.VectorTileLayer(
                theme: _noaaBathymetryTheme!,
                tileProviders: _noaaBathymetryProviders,
              ),
            if (_noaaLayersEnabled && (_moduleStates['Weather Radar'] ?? false))
              Opacity(
                opacity: _moduleOpacity['Weather Radar'] ?? 0.5,
                child: TileLayer(
                  key: ValueKey(_radarRefreshKey),
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl:
                        'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?',
                    layers: const ['1'],
                    styles: const ['default'],
                    version: '1.3.0',
                    transparent: true,
                    otherParameters: {'refresh': _radarRefreshKey.toString()},
                  ),
                  userAgentPackageName: 'com.example.starter_app',
                ),
              ),
            // Currents stay above chart and weather imagery as detail increases.
            if (_moduleStates['Current'] ?? false)
              _CurrentParticleLayer(
                animation: _currentAnimationController,
                particles: _currentParticles,
                maskAreas: _currentMaskAreas,
                currentVectors: _currentVectors,
                opacity: _moduleOpacity['Current'] ?? 0.9,
              ),
            if (_moduleStates['Wave Height'] ?? false)
              Opacity(
                opacity: _moduleOpacity['Wave Height'] ?? 0.85,
                child: MarkerLayer(markers: _buildWaveMarkers()),
              ),
            if (_moduleStates['Wind Speed'] ?? false)
              Opacity(
                opacity: _moduleOpacity['Wind Speed'] ?? 0.8,
                child: MarkerLayer(markers: _buildWindMarkers()),
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
        if (_moduleStates['Current'] ?? false)
          Positioned(
            left: 8,
            top: 8,
            child: _CurrentSourceBadge(
              label: _currentSourceLabel,
              onTap: _loadSeagullData,
            ),
          ),
        if ((_moduleStates['Wave Height'] ?? false) &&
            _buildWaveMarkers().isEmpty)
          Positioned(
            left: 8,
            top: 36,
            child: _CurrentSourceBadge(
              label:
                  'SEAGULL • WAVE ${_forecastWaves ? 'FORECAST' : 'OBSERVED'} UNAVAILABLE',
              onTap: _loadSeagullData,
            ),
          ),
        if ((_moduleStates['Wind Speed'] ?? false) &&
            _buildWindMarkers().isEmpty)
          Positioned(
            left: 8,
            top: 64,
            child: _CurrentSourceBadge(
              label:
                  'SEAGULL • WIND ${_forecastWind ? 'FORECAST' : 'OBSERVED'} UNAVAILABLE',
              onTap: _loadSeagullData,
            ),
          ),
        if ((_moduleStates['Surface Temp'] ?? false) &&
            _buildSurfaceTemperatureMarkers().isEmpty)
          Positioned(
            left: 8,
            top: 92,
            child: _CurrentSourceBadge(
              label: 'SEAGULL • SURFACE TEMP UNAVAILABLE',
              onTap: _loadSeagullData,
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF25292C), Color(0xFF090B0D), Color(0xFF020303)],
          ),
          border: Border.all(color: const Color(0xFF555B5F), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 5,
              offset: Offset(2, 3),
            ),
            BoxShadow(color: Color(0x334F575D), offset: Offset(0, -1)),
          ],
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
    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kMiddleMouseButton != 0) {
          _middleMouseModule = module;
        }
      },
      onPointerUp: (_) {
        if (_middleMouseModule == module) _middleMouseModule = null;
      },
      onPointerCancel: (_) {
        if (_middleMouseModule == module) _middleMouseModule = null;
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _middleMouseModule == module) {
          _updateOpacity(module, event.scrollDelta.dy.sign * 5);
        }
      },
      child: GestureDetector(
        onTap: () => _toggleModule(module),
        onVerticalDragUpdate: (details) =>
            _updateOpacity(module, details.delta.dy),
        child: Tooltip(
          message:
              'Tile: ON/OFF\nBottom button: data mode\nHold wheel + scroll: opacity',
          child: Container(
            margin: const EdgeInsets.fromLTRB(1, 3, 2, 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isOn
                    ? const [
                        Color(0xFF46FF4A),
                        Color(0xFF12A91A),
                        Color(0xFF063A09),
                      ]
                    : const [
                        Color(0xFF353A3E),
                        Color(0xFF15181A),
                        Color(0xFF070809),
                      ],
              ),
              border: Border.all(color: const Color(0xFF666C70), width: 1.5),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 6,
                  offset: Offset(2, 4),
                ),
                BoxShadow(
                  color: Color(0x445F686F),
                  blurRadius: 1,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 5, 4, 1),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        module
                            .replaceAll(' / ', ' /\n')
                            .replaceAll(' @ ', ' @\n'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 0.95,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CustomPaint(
                          painter: _OrangeKnobPainter(
                            value: opacity,
                            active: isOn,
                          ),
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
                GestureDetector(
                  key: ValueKey('module-mode-$module'),
                  onTap:
                      module == 'Current' ||
                          module == 'Wind Speed' ||
                          module == 'Wave Height'
                      ? () => _cycleModuleMode(module)
                      : null,
                  child: Container(
                    height: 24,
                    width: double.infinity,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF3A3E41),
                          Color(0xFF111315),
                          Color(0xFF050607),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF363A3D)),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _moduleModeLabel(module),
                        style: TextStyle(
                          color: isOn
                              ? const Color(0xFFD9FFDA)
                              : const Color(0xFFFF9A36),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          shadows: isOn
                              ? const [
                                  Shadow(
                                    color: Color(0xFF40FF48),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHardwareRail() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF373C40),
            Color(0xFF15181A),
            Color(0xFF08090A),
            Color(0xFF25292C),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4C5256), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(4, 7),
          ),
          BoxShadow(
            color: Color(0x555E666B),
            blurRadius: 2,
            offset: Offset(-1, -2),
          ),
        ],
      ),
      child: Column(
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF454A4D),
                  Color(0xFF141719),
                  Color(0xFF050607),
                ],
              ),
              border: Border.all(color: const Color(0xFF0A0B0C), width: 4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 7,
                  offset: Offset(3, 5),
                ),
                BoxShadow(color: Color(0x555C6469), offset: Offset(-1, -1)),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(
                  Icons.arrow_drop_up,
                  color: Color(0xFFFFA044),
                  size: 38,
                  shadows: [Shadow(color: Color(0xFFFF5A00), blurRadius: 12)],
                ),
                Icon(
                  Icons.arrow_drop_up,
                  color: Color(0xFFFF6A28),
                  size: 30,
                  shadows: [Shadow(color: Color(0xFFFF3D00), blurRadius: 11)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 92,
            height: 68,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66FF3D00),
                    blurRadius: 24,
                    spreadRadius: 5.6,
                  ),
                  BoxShadow(
                    color: Color(0xDDFF6A00),
                    blurRadius: 12,
                    spreadRadius: 2.4,
                  ),
                  BoxShadow(
                    color: Color(0xFFFFC36A),
                    blurRadius: 3.2,
                    spreadRadius: 0.8,
                  ),
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 8,
                    offset: Offset(3, 6),
                  ),
                ],
              ),
              child: OutlinedButton(
                onPressed: _showMenu,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFE0A8),
                  backgroundColor: const Color(0xFF111315),
                  side: const BorderSide(color: Color(0xFFFFB64D), width: 3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'MENU',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Color(0xFFFFF0C8), blurRadius: 2),
                      Shadow(color: Color(0xFFFF8A1F), blurRadius: 6.4),
                      Shadow(color: Color(0xFFFF3D00), blurRadius: 14.4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
          gradient: const RadialGradient(
            center: Alignment(0.42, -0.5),
            radius: 1.05,
            colors: [
              Color(0xFF858B8F),
              Color(0xFF303437),
              Color(0xFF08090A),
              Color(0xFF020303),
            ],
            stops: [0, 0.3, 0.76, 1],
          ),
          border: Border.all(color: const Color(0xFFFFA43B), width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55FF3D00),
              blurRadius: 22.4,
              spreadRadius: 5.6,
            ),
            BoxShadow(
              color: Color(0xCCFF6A00),
              blurRadius: 11.2,
              spreadRadius: 2.4,
            ),
            BoxShadow(
              color: Color(0xFFFFC36A),
              blurRadius: 3.2,
              spreadRadius: 0.4,
            ),
            BoxShadow(
              color: Colors.black,
              blurRadius: 9,
              spreadRadius: 1,
              offset: Offset(3, 6),
            ),
            BoxShadow(
              color: Color(0x665F686D),
              blurRadius: 2,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment(0.55, -1),
              end: Alignment(-0.15, 1),
              colors: [Color(0x447F8A90), Color(0x00121517), Color(0xAA000000)],
              stops: [0, 0.45, 1],
            ),
            border: Border.all(color: const Color(0xFFFFE0A8), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0xCCFF8A1F), blurRadius: 5.6),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFE8BE),
            size: 36,
            shadows: const [
              Shadow(color: Color(0xFFFFFFFF), blurRadius: 2),
              Shadow(color: Color(0xFFFF8A1F), blurRadius: 6.4),
              Shadow(color: Color(0xFFFF3D00), blurRadius: 12.8),
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 2)),
            ],
          ),
        ),
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
                                            PolylineLayer(
                                              polylines: _bathymetryContours,
                                            ),
                                            if (_noaaBathymetryTheme != null)
                                              vmt.VectorTileLayer(
                                                theme: _noaaBathymetryTheme!,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => MenuPanel(
        animateCurrents: _animateCurrents,
        onAnimateCurrentsChanged: _setCurrentAnimation,
        noaaLayersEnabled: _noaaLayersEnabled,
        onNoaaLayersChanged: (enabled) {
          setState(() => _noaaLayersEnabled = enabled);
        },
        alternativeBezel: _alternativeBezel,
        onAlternativeBezelChanged: (enabled) {
          setState(() => _alternativeBezel = enabled);
        },
        accentColor: _userAccentColor,
        onAccentColorChanged: (color) {
          setState(() => _userAccentColor = color);
        },
        membershipActive: _membershipActive,
      ),
    );
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
          gradient: const RadialGradient(
            center: Alignment(0.42, -0.5),
            radius: 1.05,
            colors: [
              Color(0xFF71818B),
              Color(0xFF1C2D36),
              Color(0xFF05090B),
              Color(0xFF010203),
            ],
            stops: [0, 0.32, 0.77, 1],
          ),
          border: Border.all(color: const Color(0xFF050708), width: 6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x550087FF),
              blurRadius: 28.8,
              spreadRadius: 7.2,
            ),
            BoxShadow(
              color: Color(0xDD00D9FF),
              blurRadius: 17.6,
              spreadRadius: 3.2,
            ),
            BoxShadow(
              color: Color(0xFFB8F8FF),
              blurRadius: 4,
              spreadRadius: 0.8,
            ),
            BoxShadow(color: Colors.black, blurRadius: 9, offset: Offset(4, 7)),
            BoxShadow(
              color: Color(0x8879858B),
              blurRadius: 2,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment(0.55, -1),
              end: Alignment(-0.15, 1),
              colors: [Color(0x555C7683), Color(0x00121D22), Color(0xB8000000)],
              stops: [0, 0.45, 1],
            ),
            border: Border.all(color: const Color(0xFFC8FBFF), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF00E5FF),
                blurRadius: 10.4,
                spreadRadius: 1.6,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.zoom_in,
              color: Color(0xFF9CF5FF),
              size: 30,
              shadows: [
                Shadow(color: Colors.white, blurRadius: 2),
                Shadow(color: Color(0xFF00E5FF), blurRadius: 7.2),
                Shadow(
                  color: Colors.black,
                  blurRadius: 3,
                  offset: Offset(1, 2),
                ),
              ],
            ),
          ),
        ),
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

class _ApprovedLocation extends StatelessWidget {
  const _ApprovedLocation({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF48F253), size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PlasticTexturePainter extends CustomPainter {
  const _PlasticTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final moldedSheen = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.72, -0.88),
        radius: 1.15,
        colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.72],
      ).createShader(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(4), const Radius.circular(32)),
      moldedSheen,
    );

    final grain = Paint()
      ..color = const Color(0x13FFFFFF)
      ..strokeWidth = 0.65;
    final shadowGrain = Paint()
      ..color = const Color(0x1D000000)
      ..strokeWidth = 0.75;

    for (double y = 4; y < size.height; y += 7) {
      final offset = (y ~/ 7).isEven ? 0.0 : 3.5;
      for (double x = offset; x < size.width; x += 11) {
        canvas.drawLine(Offset(x, y), Offset(x + 2.5, y + 0.8), grain);
        canvas.drawLine(
          Offset(x + 1, y + 1.8),
          Offset(x + 3.2, y + 2.4),
          shadowGrain,
        );
      }
    }

    final edgeHighlight = Paint()
      ..color = const Color(0x36FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromLTWH(7, 6, size.width - 14, size.height - 12),
      math.pi * 1.08,
      math.pi * 0.72,
      false,
      edgeHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _PlasticTexturePainter oldDelegate) => false;
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

class _EnvironmentalDataMarker extends StatelessWidget {
  const _EnvironmentalDataMarker({
    required this.icon,
    required this.value,
    required this.mode,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE6081116),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                mode,
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentSourceBadge extends StatelessWidget {
  const _CurrentSourceBadge({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC07131A),
            border: Border.all(color: const Color(0xAA7BD8FF)),
            borderRadius: BorderRadius.circular(5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD9F5FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 5),
                const Icon(Icons.refresh, size: 11, color: Color(0xFFD9F5FF)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentParticleLayer extends StatelessWidget {
  const _CurrentParticleLayer({
    required this.animation,
    required this.particles,
    required this.maskAreas,
    required this.currentVectors,
    required this.opacity,
  });

  final Animation<double> animation;
  final List<_CurrentParticle> particles;
  final List<_ParticleMaskArea> maskAreas;
  final List<_CurrentVector> currentVectors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => MobileLayerTransformer(
        child: IgnorePointer(
          child: CustomPaint(
            key: const Key('animated-current-overlay'),
            size: Size(camera.size.x, camera.size.y),
            painter: _CurrentParticlePainter(
              camera: camera,
              particles: particles,
              maskAreas: maskAreas,
              currentVectors: currentVectors,
              progress: animation.value,
              opacity: opacity,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentParticlePainter extends CustomPainter {
  const _CurrentParticlePainter({
    required this.camera,
    required this.particles,
    required this.maskAreas,
    required this.currentVectors,
    required this.progress,
    required this.opacity,
  });

  final MapCamera camera;
  final List<_CurrentParticle> particles;
  final List<_ParticleMaskArea> maskAreas;
  final List<_CurrentVector> currentVectors;
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (currentVectors.isEmpty) return;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..strokeCap = StrokeCap.round;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final particlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // A world-anchored screen grid keeps the current field populated at every
    // zoom level while remaining stable as the map is panned.
    const spacing = 46.0;
    final origin = camera.pixelOrigin;
    final firstWorldX = (origin.x / spacing).floor() * spacing;
    final firstWorldY = (origin.y / spacing).floor() * spacing;
    final samples = <_CurrentParticle>[];

    for (
      var worldY = firstWorldY;
      worldY <= origin.y + size.height + spacing;
      worldY += spacing
    ) {
      for (
        var worldX = firstWorldX;
        worldX <= origin.x + size.width + spacing;
        worldX += spacing
      ) {
        final point = camera.unproject(math.Point(worldX, worldY));
        if (!maskAreas.any((area) => area.contains(point))) continue;

        final row = (worldY / spacing).round();
        final column = (worldX / spacing).round();
        final sample = _interpolateCurrent(point, currentVectors);
        final colorPosition = ((sample.speed - 0.03) / 0.30).clamp(0.0, 1.0);
        samples.add(
          _CurrentParticle(
            point: point,
            direction:
                sample.direction +
                (_particleNoise(row, column, 3) - 0.5) * 0.12,
            speed: sample.speed,
            phase: _particleNoise(row, column, 4),
            color: Color.lerp(
              const Color(0xFF79E7FF),
              const Color(0xFFFFE27A),
              colorPosition,
            )!,
          ),
        );
      }
    }

    final visibleParticles = samples.isEmpty && maskAreas.isEmpty
        ? particles
        : samples;

    for (final particle in visibleParticles) {
      final projected = camera.project(particle.point) - origin;
      final cycle =
          (progress * (0.72 + particle.speed * 0.72) + particle.phase) % 1;
      final direction = Offset(
        math.cos(particle.direction),
        math.sin(particle.direction),
      );
      final travelDistance = 22 + particle.speed * 12;
      final position =
          Offset(projected.x, projected.y) +
          direction * ((cycle - 0.5) * travelDistance);

      if (position.dx < -20 ||
          position.dy < -20 ||
          position.dx > size.width + 20 ||
          position.dy > size.height + 20) {
        continue;
      }

      final fade = math.pow(math.sin(cycle * math.pi), 0.65).toDouble();
      final alpha = (opacity * fade).clamp(0.0, 1.0);
      final length = 7 + particle.speed * 6;
      final head = position + direction * 1.5;
      final tail = position - direction * length;

      glowPaint.color = particle.color.withValues(alpha: alpha * 0.62);
      outlinePaint.color = const Color(
        0xFF00141D,
      ).withValues(alpha: alpha * 0.9);
      particlePaint.color = particle.color.withValues(alpha: alpha);
      canvas.drawLine(tail, head, glowPaint);
      canvas.drawLine(tail, head, outlinePaint);
      canvas.drawLine(tail, head, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CurrentParticlePainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.particles != particles ||
        oldDelegate.maskAreas != maskAreas ||
        oldDelegate.currentVectors != currentVectors ||
        oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity;
  }
}

class _CurrentParticle {
  const _CurrentParticle({
    required this.point,
    required this.direction,
    required this.speed,
    required this.phase,
    required this.color,
  });

  final LatLng point;
  final double direction;
  final double speed;
  final double phase;
  final Color color;
}

enum _CurrentMode {
  surface('SURFACE'),
  atDepth('@ 9 M'),
  forecast('FORECAST');

  const _CurrentMode(this.label);

  final String label;

  _CurrentMode get next =>
      _CurrentMode.values[(index + 1) % _CurrentMode.values.length];
}

class _CurrentVector {
  const _CurrentVector(
    this.latitude,
    this.longitude,
    this.direction,
    this.speed,
  );

  final double latitude;
  final double longitude;
  final double direction;
  final double speed;
}

List<_CurrentParticle> _buildCurrentParticles(
  List<_ParticleMaskArea> masks,
  List<_CurrentVector> currentVectors,
) {
  if (currentVectors.isEmpty) return const [];
  final particles = <_CurrentParticle>[];

  const latitudeStep = 0.105;
  const longitudeStep = 0.105;
  const minLatitude = 41.62;
  const maxLatitude = 46.25;
  const minLongitude = -88.18;
  const maxLongitude = -84.75;

  var row = 0;
  for (
    var latitude = minLatitude;
    latitude <= maxLatitude;
    latitude += latitudeStep
  ) {
    var column = 0;
    for (
      var longitude = minLongitude;
      longitude <= maxLongitude;
      longitude += longitudeStep
    ) {
      final point = LatLng(
        latitude + (_particleNoise(row, column, 1) - 0.5) * 0.072,
        longitude + (_particleNoise(row, column, 2) - 0.5) * 0.072,
      );
      column++;

      if (!masks.any((area) => area.contains(point))) continue;

      final sample = _interpolateCurrent(point, currentVectors);
      final speedColorPosition = ((sample.speed - 0.03) / 0.30).clamp(0.0, 1.0);
      particles.add(
        _CurrentParticle(
          point: point,
          direction:
              sample.direction + (_particleNoise(row, column, 3) - 0.5) * 0.16,
          speed: sample.speed,
          phase: _particleNoise(row, column, 4),
          color: Color.lerp(
            const Color(0xFF6EDBFF),
            const Color(0xFFFFD166),
            speedColorPosition,
          )!,
        ),
      );
    }
    row++;
  }

  return particles;
}

_CurrentSample _interpolateCurrent(
  LatLng point,
  List<_CurrentVector> currentVectors,
) {
  var horizontalFlow = 0.0;
  var verticalFlow = 0.0;
  var weightedSpeed = 0.0;
  var totalWeight = 0.0;
  final longitudeScale = math.cos(point.latitude * math.pi / 180);

  for (final vector in currentVectors) {
    final dx = (point.longitude - vector.longitude) * longitudeScale;
    final dy = point.latitude - vector.latitude;
    final weight = 1 / (dx * dx + dy * dy + 0.035);
    horizontalFlow += math.cos(vector.direction) * vector.speed * weight;
    verticalFlow += math.sin(vector.direction) * vector.speed * weight;
    weightedSpeed += vector.speed * weight;
    totalWeight += weight;
  }

  final direction =
      math.atan2(verticalFlow, horizontalFlow) +
      math.sin(point.latitude * 2.7 + point.longitude * 3.1) * 0.07;
  return _CurrentSample(
    direction: direction,
    speed: (weightedSpeed / totalWeight).clamp(0.01, 1.0),
  );
}

double _particleNoise(int row, int column, int salt) {
  final value =
      math.sin(row * 12.9898 + column * 78.233 + salt * 37.719) * 43758.5453;
  return value - value.floorToDouble();
}

class _CurrentSample {
  const _CurrentSample({required this.direction, required this.speed});

  final double direction;
  final double speed;
}

class _ParticleMaskArea {
  _ParticleMaskArea(List<List<LatLng>> rings)
    : outer = _ParticleMaskRing(rings.first, maxPoints: 1800),
      holes = rings
          .skip(1)
          .map((ring) => _ParticleMaskRing(ring, maxPoints: 240))
          .toList();

  final _ParticleMaskRing outer;
  final List<_ParticleMaskRing> holes;

  bool contains(LatLng point) {
    return outer.contains(point) && !holes.any((ring) => ring.contains(point));
  }
}

class _ParticleMaskRing {
  _ParticleMaskRing(List<LatLng> source, {required int maxPoints})
    : points = _simplifyRing(source, maxPoints) {
    for (final point in points) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }
  }

  final List<LatLng> points;
  double minLatitude = double.infinity;
  double maxLatitude = double.negativeInfinity;
  double minLongitude = double.infinity;
  double maxLongitude = double.negativeInfinity;

  bool contains(LatLng point) {
    if (point.latitude < minLatitude ||
        point.latitude > maxLatitude ||
        point.longitude < minLongitude ||
        point.longitude > maxLongitude) {
      return false;
    }

    var inside = false;
    for (
      var current = 0, previous = points.length - 1;
      current < points.length;
      previous = current++
    ) {
      final a = points[current];
      final b = points[previous];
      final crossesLatitude =
          (a.latitude > point.latitude) != (b.latitude > point.latitude);
      if (!crossesLatitude) continue;

      final crossingLongitude =
          (b.longitude - a.longitude) *
              (point.latitude - a.latitude) /
              (b.latitude - a.latitude) +
          a.longitude;
      if (point.longitude < crossingLongitude) inside = !inside;
    }
    return inside;
  }
}

List<LatLng> _simplifyRing(List<LatLng> points, int maxPoints) {
  if (points.length <= maxPoints) return points;
  final stride = (points.length / maxPoints).ceil();
  return [
    for (var index = 0; index < points.length; index += stride) points[index],
    if (points.last != points[(points.length - 1) ~/ stride * stride])
      points.last,
  ];
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

    canvas.drawCircle(
      center + const Offset(2.5, 3.5),
      radius + 2,
      Paint()
        ..color = const Color(0xCC000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    if (active) {
      canvas.drawCircle(
        center,
        radius + 4,
        Paint()
          ..color = const Color(0x33FF3D00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        center,
        radius + 3,
        Paint()
          ..color = const Color(0x77FF6A00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.2),
      );
      canvas.drawCircle(
        center,
        radius + 1,
        Paint()
          ..color = const Color(0xCCFFC36A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
    }

    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment(-0.18, 1),
          colors: [Color(0xFF8A8F91), Color(0xFF17191A), Color(0xFF020303)],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 2)),
    );

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.45, -0.5),
          radius: 1.05,
          colors: [
            Color(0xFF666A6D),
            Color(0xFF252728),
            Color(0xFF090A0A),
            Color(0xFF010101),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = active ? const Color(0xFFFF8A1A) : const Color(0xFF5A3B17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      -math.pi * 0.45,
      math.pi * 0.40,
      false,
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    for (var index = 0; index < 9; index++) {
      final tickAngle = -math.pi * 0.75 + index * (math.pi * 1.5 / 8);
      final tickStart = Offset(
        center.dx + (radius + 1) * math.cos(tickAngle),
        center.dy + (radius + 1) * math.sin(tickAngle),
      );
      final tickEnd = Offset(
        center.dx + (radius + 4) * math.cos(tickAngle),
        center.dy + (radius + 4) * math.sin(tickAngle),
      );
      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = active ? const Color(0xFFFFB15A) : const Color(0xFF5C5F61)
          ..strokeWidth = 1.2,
      );
    }

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
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Color(0xFF5D6163), Color(0xFF050505)],
        ).createShader(Rect.fromCircle(center: center, radius: 5)),
    );
  }

  @override
  bool shouldRepaint(covariant _OrangeKnobPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.active != active;
}

class MenuPanel extends StatefulWidget {
  const MenuPanel({
    super.key,
    required this.animateCurrents,
    required this.onAnimateCurrentsChanged,
    this.noaaLayersEnabled = false,
    this.onNoaaLayersChanged,
    this.alternativeBezel = false,
    this.onAlternativeBezelChanged,
    this.accentColor = const Color(0xFFFF8A1A),
    this.onAccentColorChanged,
    this.membershipActive = false,
  });

  final bool animateCurrents;
  final ValueChanged<bool> onAnimateCurrentsChanged;
  final bool noaaLayersEnabled;
  final ValueChanged<bool>? onNoaaLayersChanged;
  final bool alternativeBezel;
  final ValueChanged<bool>? onAlternativeBezelChanged;
  final Color accentColor;
  final ValueChanged<Color>? onAccentColorChanged;
  final bool membershipActive;

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  late bool _animateCurrents;
  late bool _noaaLayersEnabled;
  late bool _alternativeBezel;
  late Color _accentColor;

  @override
  void initState() {
    super.initState();
    _animateCurrents = widget.animateCurrents;
    _noaaLayersEnabled = widget.noaaLayersEnabled;
    _alternativeBezel = widget.alternativeBezel;
    _accentColor = widget.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 400 ? 14.0 : 22.0;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.92,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          28,
        ),
        decoration: BoxDecoration(
          color: Color(0xFF0B1114),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: _accentColor, width: 2)),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.28),
              blurRadius: 24,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF536068),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.tune, color: Color(0xFF53FF5A), size: 27),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'MAIN MENU  /  SETTINGS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17311E), Color(0xFF101719)],
                  ),
                  border: Border.all(
                    color: _animateCurrents
                        ? const Color(0xFF48F253)
                        : const Color(0xFF3D484D),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _animateCurrents
                      ? const [
                          BoxShadow(color: Color(0x443CFF48), blurRadius: 16),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF082C34),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.air,
                        color: Color(0xFF72F4FF),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Animated currents',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Smooth particle flow over the Current data layer',
                            style: TextStyle(
                              color: Color(0xFF9DAEB5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('animated-current-switch'),
                      value: _animateCurrents,
                      activeThumbColor: const Color(0xFFE8FFEA),
                      activeTrackColor: const Color(0xFF25C92D),
                      onChanged: (enabled) {
                        setState(() => _animateCurrents = enabled);
                        widget.onAnimateCurrentsChanged(enabled);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _settingsSection(),
              const SizedBox(height: 16),
              _membershipSection(context),
              const SizedBox(height: 16),
              _tournamentSection(context),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(
                    Icons.mouse_outlined,
                    color: Color(0xFFFFA24B),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Overlay controls: left-click toggles ON/OFF. '
                      'Hold the mouse wheel and scroll to adjust opacity.',
                      style: TextStyle(color: Color(0xFFABB7BC), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsSection() {
    const colors = <Color>[
      Color(0xFFFF8A1A),
      Color(0xFF48F253),
      Color(0xFF45D9FF),
      Color(0xFFB36CFF),
      Color(0xFFFF4D6D),
    ];
    return _menuSection(
      title: 'DISPLAY & DATA',
      icon: Icons.palette_outlined,
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('noaa-data-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'NOAA supplemental layers',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Optional NOAA radar; bath charts stay on until Navionics is available',
              style: TextStyle(color: Color(0xFF9DAEB5)),
            ),
            value: _noaaLayersEnabled,
            activeThumbColor: _accentColor,
            onChanged: (enabled) {
              setState(() => _noaaLayersEnabled = enabled);
              widget.onNoaaLayersChanged?.call(enabled);
            },
          ),
          const Divider(color: Color(0xFF28363D)),
          SwitchListTile(
            key: const Key('alternate-bezel-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Alternative bezel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Switch to the dark marine-blue hardware shell',
              style: TextStyle(color: Color(0xFF9DAEB5)),
            ),
            value: _alternativeBezel,
            activeThumbColor: _accentColor,
            onChanged: (enabled) {
              setState(() => _alternativeBezel = enabled);
              widget.onAlternativeBezelChanged?.call(enabled);
            },
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CUSTOM ACCENT COLOR',
              style: TextStyle(
                color: Color(0xFF9DAEB5),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: colors.map((color) {
              final selected = color.toARGB32() == _accentColor.toARGB32();
              return InkWell(
                key: ValueKey('accent-${color.toARGB32()}'),
                onTap: () {
                  setState(() => _accentColor = color);
                  widget.onAccentColorChanged?.call(color);
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: selected ? 12 : 4,
                      ),
                    ],
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.black, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _membershipSection(BuildContext context) {
    const features = <(IconData, String, String)>[
      (Icons.menu_book, "Captain's Log", 'Private trip history and notes'),
      (Icons.photo_camera, 'Bragging Board', 'Share verified catches'),
      (Icons.forum, 'The Galley', 'Members-only fishing chat'),
      (Icons.share_location, 'Share Intel', 'Share spots and conditions'),
      (Icons.local_fire_department, 'Hot Tackle', 'Community tackle trends'),
      (Icons.auto_graph, 'Projected Report', 'Forward-looking fishing report'),
      (Icons.summarize, 'Current Report', 'Member current fishing report'),
    ];
    return _menuSection(
      title: 'LAKEGUARD MEMBERSHIP',
      icon: Icons.workspace_premium,
      trailing: _statusPill(
        widget.membershipActive ? 'MEMBER' : 'FREE',
        widget.membershipActive ? const Color(0xFF48F253) : Colors.white54,
      ),
      child: Column(
        children: [
          ...features.map(
            (feature) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(feature.$1, color: _accentColor),
              title: Text(
                feature.$2,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                feature.$3,
                style: const TextStyle(color: Color(0xFF9DAEB5)),
              ),
              trailing: Icon(
                widget.membershipActive ? Icons.chevron_right : Icons.lock,
                color: widget.membershipActive
                    ? _accentColor
                    : const Color(0xFF68777E),
              ),
              onTap: () => _openMemberFeature(context, feature.$2, feature.$3),
            ),
          ),
          if (!widget.membershipActive)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('view-membership-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _showMembershipInfo(context),
                icon: const Icon(Icons.workspace_premium),
                label: const Text(
                  'VIEW MEMBERSHIP',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tournamentSection(BuildContext context) {
    return _menuSection(
      title: 'MONTHLY BIG-FISH TOURNAMENTS',
      icon: Icons.emoji_events,
      trailing: _statusPill('SEPARATE ENTRY', const Color(0xFFFFC04D)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biggest verified fish wins in each targeted species category.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Membership unlocks tournament access. Tournament entry fees are '
            'paid separately; membership dues do not fund prize pools.',
            style: TextStyle(color: Color(0xFFFFD27A), height: 1.35),
          ),
          const SizedBox(height: 14),
          const Text(
            'APPROVED WEIGH-SLIP LOCATIONS',
            style: TextStyle(
              color: Color(0xFF9DAEB5),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          const _ApprovedLocation(name: 'Tangled Tackle'),
          const _ApprovedLocation(name: "Larry's Gas Dock"),
          const _ApprovedLocation(name: 'Ludington Tackle Shop'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('tournament-entry-button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentColor,
                side: BorderSide(color: _accentColor),
              ),
              onPressed: () => _showTournamentInfo(context),
              icon: Icon(
                widget.membershipActive ? Icons.upload_file : Icons.lock,
              ),
              label: Text(
                widget.membershipActive
                    ? 'ENTER & UPLOAD WEIGH SLIP'
                    : 'MEMBERSHIP REQUIRED',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Material(
      color: const Color(0xFF101719),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF28363D)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _accentColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _openMemberFeature(
    BuildContext context,
    String title,
    String description,
  ) {
    if (!widget.membershipActive) {
      _showMembershipInfo(context);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _showMembershipInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LakeGuard Membership'),
        content: const Text(
          "Membership unlocks Captain's Log, Bragging Board, The Galley, "
          'shared fishing intelligence, Hot Tackle, and projected/current '
          'reports. Tournament entry fees remain separate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NOT NOW'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CHOOSE A PLAN'),
          ),
        ],
      ),
    );
  }

  void _showTournamentInfo(BuildContext context) {
    if (!widget.membershipActive) {
      _showMembershipInfo(context);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tournament Entry'),
        content: const Text(
          'Choose a targeted species, pay that tournament’s separate entry '
          'fee, then upload a readable weigh slip from Tangled Tackle, '
          "Larry's Gas Dock, or Ludington Tackle Shop.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
