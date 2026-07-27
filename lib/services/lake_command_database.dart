import 'package:flutter/foundation.dart';
import '../models/observation_models.dart';

/// Lake Command central database for storing all agent observations
/// Implements a central intelligence repository that never discards data
class LakeCommandDatabase extends ChangeNotifier {
  final Map<String, ObservationEnvelope> _observations = {};
  final Map<String, EnvironmentalSnapshot> _environmentalSnapshots = {};
  final Map<String, CaptainReport> _captainReports = {};
  final Map<String, FishHeatMapData> _heatMapData = {};
  final Map<String, LurePerformanceRecord> _lurePerformance = {};

  // Getters for read access
  Map<String, ObservationEnvelope> get observations =>
      Map.unmodifiable(_observations);

  Map<String, EnvironmentalSnapshot> get environmentalSnapshots =>
      Map.unmodifiable(_environmentalSnapshots);

  Map<String, CaptainReport> get captainReports =>
      Map.unmodifiable(_captainReports);

  Map<String, FishHeatMapData> get heatMapData =>
      Map.unmodifiable(_heatMapData);

  Map<String, LurePerformanceRecord> get lurePerformance =>
      Map.unmodifiable(_lurePerformance);

  /// Store a new observation or update existing
  void storeObservation(ObservationEnvelope observation) {
    _observations[observation.id] = observation;
    notifyListeners();
  }

  /// Store environmental snapshot
  void storeEnvironmentalSnapshot(EnvironmentalSnapshot snapshot) {
    _environmentalSnapshots[snapshot.id] = snapshot;
    notifyListeners();
  }

  /// Store parsed captain report
  void storeCaptainReport(CaptainReport report) {
    _captainReports[report.id] = report;
    notifyListeners();
  }

  /// Store or update fish heat map data
  void storeHeatMapData(FishHeatMapData data) {
    _heatMapData[data.id] = data;
    notifyListeners();
  }

  /// Store lure performance record
  void storeLurePerformance(LurePerformanceRecord record) {
    _lurePerformance[record.id] = record;
    notifyListeners();
  }

  /// Query observations by species
  List<ObservationEnvelope> getObservationsBySpecies(String species) {
    return _observations.values
        .where((obs) =>
            obs.fishActivity?.speciesSignals
                .any((signal) => signal.species == species) ??
            false)
        .toList();
  }

  /// Query observations by location
  List<ObservationEnvelope> getObservationsByLocation(String areaLabel) {
    return _observations.values
        .where((obs) => obs.location.areaLabel == areaLabel)
        .toList();
  }

  /// Query observations by date range
  List<ObservationEnvelope> getObservationsByDateRange(
      DateTime start, DateTime end) {
    return _observations.values
        .where((obs) =>
            obs.observedAt.isAfter(start) && obs.observedAt.isBefore(end))
        .toList();
  }

  /// Get recent environmental conditions
  List<EnvironmentalSnapshot> getRecentEnvironmental(int hours) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    return _environmentalSnapshots.values
        .where((snapshot) => snapshot.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Calculate average confidence decay for an observation
  /// Confidence decreases over time
  double getAdjustedConfidence(ObservationEnvelope observation) {
    final hoursSinceObservation =
        DateTime.now().difference(observation.observedAt).inHours;
    final freshnessHours =
        observation.confidenceMetadata?.freshnessHours ?? 24;
    final decayFactor = (1 - (hoursSinceObservation / freshnessHours))
        .clamp(0.0, 1.0);
    final baseConfidence =
        observation.confidenceMetadata?.sourceCredibility ?? 0.7;

    return baseConfidence * decayFactor;
  }

  /// Get high-confidence observations (above threshold)
  List<ObservationEnvelope> getHighConfidenceObservations({
    double threshold = 0.5,
    int withinHours = 72,
  }) {
    final cutoff = DateTime.now().subtract(Duration(hours: withinHours));
    return _observations.values
        .where((obs) =>
            obs.observedAt.isAfter(cutoff) &&
            getAdjustedConfidence(obs) >= threshold)
        .toList();
  }

  /// Get successful lure combinations
  List<LurePerformanceRecord> getSuccessfulLures({
    String? species,
    double? minSuccessRate = 0.5,
  }) {
    var records = _lurePerformance.values.toList();

    if (species != null) {
      records = records.where((r) => r.species == species).toList();
    }

    if (minSuccessRate != null) {
      records = records.where((r) => r.successRate >= minSuccessRate).toList();
    }

    records.sort((a, b) => b.successRate.compareTo(a.successRate));
    return records;
  }

  /// Get captain reports for specific species
  List<CaptainReport> getCaptainReportsBySpecies(String species) {
    return _captainReports.values
        .where((report) => report.species == species)
        .toList();
  }

  /// Clear all data (for testing)
  void clear() {
    _observations.clear();
    _environmentalSnapshots.clear();
    _captainReports.clear();
    _heatMapData.clear();
    _lurePerformance.clear();
    notifyListeners();
  }

  /// Get database statistics
  DatabaseStats getStats() {
    return DatabaseStats(
      observationCount: _observations.length,
      environmentalSnapshotCount: _environmentalSnapshots.length,
      captainReportCount: _captainReports.length,
      heatMapDataPoints: _heatMapData.length,
      lureRecords: _lurePerformance.length,
    );
  }
}

/// Environmental snapshot from collector agent
class EnvironmentalSnapshot {
  const EnvironmentalSnapshot({
    required this.id,
    required this.timestamp,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.waveHeight,
    required this.barometricPressure,
    this.moonPhase,
    this.sunriseTime,
    this.sunsetTime,
  });

  final String id;
  final DateTime timestamp;
  final double temperature;
  final double windSpeed;
  final String windDirection;
  final double waveHeight;
  final double barometricPressure;
  final String? moonPhase;
  final DateTime? sunriseTime;
  final DateTime? sunsetTime;
}

/// Parsed captain report
class CaptainReport {
  const CaptainReport({
    required this.id,
    required this.captainName,
    required this.reportDate,
    required this.species,
    required this.depth,
    required this.speed,
    required this.lure,
    required this.color,
    required this.catchCount,
    required this.waterTemp,
    required this.waterClarity,
    required this.location,
    required this.confidence,
  });

  final String id;
  final String captainName;
  final DateTime reportDate;
  final String species;
  final double depth;
  final double speed;
  final String lure;
  final String color;
  final int catchCount;
  final double waterTemp;
  final String waterClarity;
  final String location;
  final double confidence;
}

/// Fish heat map data point
class FishHeatMapData {
  const FishHeatMapData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.species,
    required this.intensity,
    required this.depth,
    required this.timestamp,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String species;
  final double intensity; // 0.0 to 1.0
  final double depth;
  final DateTime timestamp;
}

/// Lure performance record
class LurePerformanceRecord {
  const LurePerformanceRecord({
    required this.id,
    required this.lure,
    required this.color,
    required this.species,
    required this.speed,
    required this.depth,
    required this.successRate,
    required this.catches,
    required this.attempts,
    required this.lastUsed,
  });

  final String id;
  final String lure;
  final String color;
  final String species;
  final double speed;
  final double depth;
  final double successRate;
  final int catches;
  final int attempts;
  final DateTime lastUsed;
}

/// Database statistics
class DatabaseStats {
  const DatabaseStats({
    required this.observationCount,
    required this.environmentalSnapshotCount,
    required this.captainReportCount,
    required this.heatMapDataPoints,
    required this.lureRecords,
  });

  final int observationCount;
  final int environmentalSnapshotCount;
  final int captainReportCount;
  final int heatMapDataPoints;
  final int lureRecords;

  int get totalRecords =>
      observationCount +
      environmentalSnapshotCount +
      captainReportCount +
      heatMapDataPoints +
      lureRecords;
}
