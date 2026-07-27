import 'dart:async';
import 'package:flutter/foundation.dart';
import 'lake_command_event_bus.dart';
import 'lake_command_database.dart';

/// Agent 1 - Environmental Collector
/// Continuously gathers environmental conditions and publishes structured data
class EnvironmentalCollectorAgent {
  EnvironmentalCollectorAgent({
    required this.eventBus,
    required this.database,
  });

  final LakeCommandEventBus eventBus;
  final LakeCommandDatabase database;

  Timer? _collectionTimer;
  bool _isActive = false;

  bool get isActive => _isActive;

  /// Start the environmental collector
  void start({Duration interval = const Duration(minutes: 15)}) {
    if (_isActive) return;

    _isActive = true;
    if (kDebugMode) {
      print('[EnvironmentalCollectorAgent] Started');
    }

    // Initial collection
    _collectEnvironmentalData();

    // Schedule periodic collection
    _collectionTimer = Timer.periodic(interval, (_) {
      _collectEnvironmentalData();
    });
  }

  /// Stop the environmental collector
  void stop() {
    _collectionTimer?.cancel();
    _isActive = false;
    if (kDebugMode) {
      print('[EnvironmentalCollectorAgent] Stopped');
    }
  }

  /// Collect environmental data from various sources
  void _collectEnvironmentalData() {
    final timestamp = DateTime.now();
    final snapshot = EnvironmentalSnapshot(
      id: 'env_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      temperature: _fetchSurfaceTemperature(),
      windSpeed: _fetchWindSpeed(),
      windDirection: _fetchWindDirection(),
      waveHeight: _fetchWaveHeight(),
      barometricPressure: _fetchBarometricPressure(),
      moonPhase: _calculateMoonPhase(),
      sunriseTime: _calculateSunrise(),
      sunsetTime: _calculateSunset(),
    );

    // Store in database
    database.storeEnvironmentalSnapshot(snapshot);

    // Emit event for other agents
    eventBus.emit(
      EnvironmentalUpdateEvent(
        temperature: snapshot.temperature,
        windSpeed: snapshot.windSpeed,
        windDirection: snapshot.windDirection,
        waveHeight: snapshot.waveHeight,
        pressure: snapshot.barometricPressure,
        timestamp: timestamp,
      ),
    );

    if (kDebugMode) {
      print(
        '[EnvironmentalCollectorAgent] Collected data: '
        'Temp: ${snapshot.temperature}°F, '
        'Wind: ${snapshot.windSpeed} kt, '
        'Waves: ${snapshot.waveHeight} ft',
      );
    }
  }

  /// Fetch surface temperature (simulated - in production would call API)
  double _fetchSurfaceTemperature() {
    // Simulated data with realistic variation
    // In production: fetch from NOAA API, buoy data, etc.
    return 48.0 + (DateTime.now().millisecondsSinceEpoch % 120) / 120.0 * 10.0;
  }

  /// Fetch wind speed (simulated)
  double _fetchWindSpeed() {
    // Simulated in knots
    // In production: fetch from weather API
    return 8.0 + (DateTime.now().millisecondsSinceEpoch % 150) / 150.0 * 15.0;
  }

  /// Fetch wind direction (simulated)
  String _fetchWindDirection() {
    final hour = DateTime.now().hour;
    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[hour % directions.length];
  }

  /// Fetch wave height (simulated)
  double _fetchWaveHeight() {
    // Simulated in feet
    return 2.0 + (DateTime.now().millisecondsSinceEpoch % 100) / 100.0 * 4.0;
  }

  /// Fetch barometric pressure (simulated)
  double _fetchBarometricPressure() {
    // Simulated in inches of mercury
    return 29.8 + (DateTime.now().millisecondsSinceEpoch % 50) / 50.0 * 0.4;
  }

  /// Calculate current moon phase
  String _calculateMoonPhase() {
    final now = DateTime.now();
    // Simplified moon phase calculation
    // In production: use proper lunar calendar calculation
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final phase = (dayOfYear % 29.5).toInt();

    if (phase < 7) return 'New Moon';
    if (phase < 14) return 'First Quarter';
    if (phase < 22) return 'Full Moon';
    return 'Last Quarter';
  }

  /// Calculate sunrise time
  DateTime _calculateSunrise() {
    final now = DateTime.now();
    // Simplified calculation for 42.5°N, 86.4°W (Lake Michigan)
    // In production: use proper solar calculation library
    return DateTime(now.year, now.month, now.day, 6, 45);
  }

  /// Calculate sunset time
  DateTime _calculateSunset() {
    final now = DateTime.now();
    // Simplified calculation for 42.5°N, 86.4°W
    return DateTime(now.year, now.month, now.day, 20, 15);
  }

  /// Manually inject environmental data (for testing/simulation)
  void injectEnvironmentalData({
    required double temperature,
    required double windSpeed,
    required String windDirection,
    required double waveHeight,
    required double pressure,
  }) {
    final timestamp = DateTime.now();
    final snapshot = EnvironmentalSnapshot(
      id: 'env_injected_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      temperature: temperature,
      windSpeed: windSpeed,
      windDirection: windDirection,
      waveHeight: waveHeight,
      barometricPressure: pressure,
      moonPhase: _calculateMoonPhase(),
      sunriseTime: _calculateSunrise(),
      sunsetTime: _calculateSunset(),
    );

    database.storeEnvironmentalSnapshot(snapshot);
    eventBus.emit(
      EnvironmentalUpdateEvent(
        temperature: temperature,
        windSpeed: windSpeed,
        windDirection: windDirection,
        waveHeight: waveHeight,
        pressure: pressure,
        timestamp: timestamp,
      ),
    );

    if (kDebugMode) {
      print('[EnvironmentalCollectorAgent] Injected environmental data');
    }
  }

  /// Get latest environmental conditions
  EnvironmentalSnapshot? getLatestConditions() {
    final snapshots = database.environmentalSnapshots.values.toList();
    if (snapshots.isEmpty) return null;
    snapshots.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return snapshots.first;
  }
}
