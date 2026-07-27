import 'package:flutter/foundation.dart';
import 'lake_command_event_bus.dart';
import 'lake_command_database.dart';

/// Agent 2 - Fish Intelligence Agent
/// Estimates fish location and movement based on available data
class FishIntelligenceAgent {
  FishIntelligenceAgent({
    required this.eventBus,
    required this.database,
  });

  final LakeCommandEventBus eventBus;
  final LakeCommandDatabase database;

  final Map<String, FishIntelligenceModel> _speciesModels = {};

  /// Initialize fish intelligence models for target species
  void initializeSpeciesModels(List<String> species) {
    for (final sp in species) {
      _speciesModels[sp] = FishIntelligenceModel(species: sp);
    }
    if (kDebugMode) {
      print('[FishIntelligenceAgent] Initialized models for $species');
    }
  }

  /// Process captain reports to update fish intelligence
  void processReport(CaptainReport report) {
    final model = _speciesModels[report.species];
    if (model == null) {
      if (kDebugMode) {
        print('[FishIntelligenceAgent] No model for ${report.species}');
      }
      return;
    }

    // Update the model with new data
    model.addObservation(
      depth: report.depth,
      timestamp: report.reportDate,
      catchCount: report.catchCount,
      waterTemp: report.waterTemp,
    );

    // Calculate updated depth ranges
    final depthRange = model.getProbableDepthRange();

    // Emit event for other agents
    eventBus.emit(
      FishIntelligenceUpdateEvent(
        species: report.species,
        depthRange: depthRange,
        confidence: model.getConfidence(),
        timestamp: DateTime.now(),
      ),
    );

    if (kDebugMode) {
      print(
        '[FishIntelligenceAgent] Updated ${report.species} model: '
        '${depthRange.minFeet} - ${depthRange.maxFeet} ft',
      );
    }
  }

  /// Get probable depth range for a species
  DepthRange? getDepthRange(String species) {
    return _speciesModels[species]?.getProbableDepthRange();
  }

  /// Get active depth ranges based on current conditions
  Map<String, DepthRange> getActiveDepthRanges({
    required double currentWaterTemp,
    required String waterClarity,
  }) {
    final ranges = <String, DepthRange>{};

    for (final entry in _speciesModels.entries) {
      final model = entry.value;

      // Adjust depth based on water conditions
      var depthRange = model.getProbableDepthRange();

      // Adjust based on temperature
      if (currentWaterTemp < 50) {
        // Cold water - fish deeper
        depthRange = DepthRange(
          minFeet: (depthRange.minFeet * 1.1).clamp(20, 200),
          maxFeet: (depthRange.maxFeet * 1.1).clamp(20, 200),
        );
      } else if (currentWaterTemp > 60) {
        // Warm water - fish shallower
        depthRange = DepthRange(
          minFeet: (depthRange.minFeet * 0.9).clamp(10, 150),
          maxFeet: (depthRange.maxFeet * 0.9).clamp(10, 150),
        );
      }

      // Adjust based on clarity
      if (waterClarity == 'Clear') {
        // Clear water - fish deeper for light sensitivity
        depthRange = DepthRange(
          minFeet: (depthRange.minFeet * 1.2).clamp(20, 250),
          maxFeet: (depthRange.maxFeet * 1.2).clamp(20, 250),
        );
      } else if (waterClarity == 'Muddy') {
        // Muddy water - fish shallower, easier visibility
        depthRange = DepthRange(
          minFeet: (depthRange.minFeet * 0.7).clamp(10, 100),
          maxFeet: (depthRange.maxFeet * 0.7).clamp(10, 100),
        );
      }

      ranges[entry.key] = depthRange;
    }

    return ranges;
  }

  /// Get migration trends for a species
  MigrationTrend? getMigrationTrend(String species) {
    return _speciesModels[species]?.getMigrationTrend();
  }

  /// Get all species models
  Map<String, FishIntelligenceModel> getSpeciesModels() {
    return Map.unmodifiable(_speciesModels);
  }

  /// Clear models (for testing)
  void clear() {
    _speciesModels.clear();
  }
}

/// Fish Intelligence Model for tracking species-specific data
class FishIntelligenceModel {
  FishIntelligenceModel({required this.species});

  final String species;
  final List<FishObservation> _observations = [];

  /// Add an observation
  void addObservation({
    required double depth,
    required DateTime timestamp,
    required int catchCount,
    required double waterTemp,
  }) {
    _observations.add(
      FishObservation(
        depth: depth,
        timestamp: timestamp,
        catchCount: catchCount,
        waterTemp: waterTemp,
      ),
    );
  }

  /// Get probable depth range
  DepthRange getProbableDepthRange() {
    if (_observations.isEmpty) {
      // Default ranges by species
      switch (species) {
        case 'King Salmon':
          return const DepthRange(minFeet: 40, maxFeet: 120);
        case 'Coho Salmon':
          return const DepthRange(minFeet: 30, maxFeet: 80);
        case 'Steelhead':
          return const DepthRange(minFeet: 20, maxFeet: 60);
        case 'Lake Trout':
          return const DepthRange(minFeet: 60, maxFeet: 150);
        default:
          return const DepthRange(minFeet: 30, maxFeet: 100);
      }
    }

    // Calculate average depth and standard deviation
    final depths = _observations.map((o) => o.depth).toList();
    depths.sort();

    final meanDepth = depths.reduce((a, b) => a + b) / depths.length;

    // Use mean ± std deviation as range
    final stdDev = _calculateStdDev(depths, meanDepth);

    return DepthRange(
      minFeet: (meanDepth - stdDev).clamp(10, 250),
      maxFeet: (meanDepth + stdDev).clamp(10, 250),
    );
  }

  /// Get migration trend
  MigrationTrend? getMigrationTrend() {
    if (_observations.length < 2) return null;

    // Check if recent observations show movement
    final recent = _observations.length > 5
        ? _observations.sublist(_observations.length - 5)
        : _observations;

    final oldAvg = _observations.take((_observations.length / 2).toInt())
            .map((o) => o.depth)
            .reduce((a, b) => a + b) /
        (_observations.length / 2);

    final newAvg = recent.map((o) => o.depth).reduce((a, b) => a + b) /
        recent.length;

    final depthChange = newAvg - oldAvg;

    if (depthChange.abs() < 5) {
      return MigrationTrend.stable;
    } else if (depthChange > 0) {
      return MigrationTrend.deeper;
    } else {
      return MigrationTrend.shallower;
    }
  }

  /// Get confidence score
  double getConfidence() {
    if (_observations.isEmpty) return 0.3;
    if (_observations.length < 3) return 0.5;

    // Higher confidence with more recent observations
    final recentObs = _observations.where((o) {
      final hoursSince =
          DateTime.now().difference(o.timestamp).inHours;
      return hoursSince < 72; // 3 days
    }).length;

    final baseConfidence = (_observations.length / 20.0).clamp(0.0, 0.9);
    final recencyBonus = recentObs > 0 ? 0.2 : 0.0;

    return (baseConfidence + recencyBonus).clamp(0.3, 1.0);
  }

  double _calculateStdDev(List<double> values, double mean) {
    if (values.isEmpty) return 0;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return variance.isNaN ? 0 : variance.sqrt();
  }
}

/// Individual fish observation
class FishObservation {
  const FishObservation({
    required this.depth,
    required this.timestamp,
    required this.catchCount,
    required this.waterTemp,
  });

  final double depth;
  final DateTime timestamp;
  final int catchCount;
  final double waterTemp;
}

/// Fish migration trend
enum MigrationTrend {
  shallower,
  stable,
  deeper,
}

/// Extension for sqrt
extension on double {
  double sqrt() {
    return this < 0 ? 0 : _sqrt();
  }

  double _sqrt() {
    if (this == 0) return 0;
    var x = this;
    var y = 0.0;
    var b = 1.0;
    while (b < x) {
      b *= 2;
    }
    while (b != 1) {
      if (x >= y + b) {
        x -= y + b;
        y += 2 * b;
      }
      b = b / 4;
    }
    return y / 2;
  }
}
