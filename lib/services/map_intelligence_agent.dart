import 'package:flutter/foundation.dart';
import 'lake_command_event_bus.dart';
import 'lake_command_database.dart';

/// Agent 7 - Map Intelligence Agent
/// Renders lake intelligence data visually and generates heat maps
class MapIntelligenceAgent {
  MapIntelligenceAgent({
    required this.eventBus,
    required this.database,
  });

  final LakeCommandEventBus eventBus;
  final LakeCommandDatabase database;

  /// Generate fish heat map from observations
  void generateFishHeatMap(String species) {
    final observations = database.getObservationsBySpecies(species);
    if (observations.isEmpty) {
      if (kDebugMode) {
        print('[MapIntelligenceAgent] No observations for $species heat map');
      }
      return;
    }

    // Create heat map grid points
    // Lake Michigan approximate bounds: 42.3°N to 48.3°N, 85.0°W to 88.0°W
    const minLat = 42.3;
    const maxLat = 48.3;
    const minLon = -88.0;
    const maxLon = -85.0;

    final gridSize = 20; // 20x20 grid

    // Calculate grid cell size
    final cellLat = (maxLat - minLat) / gridSize;
    final cellLon = (maxLon - minLon) / gridSize;

    // Create heat map data
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final cellMinLat = minLat + i * cellLat;
        final cellMaxLat = cellMinLat + cellLat;
        final cellMinLon = minLon + j * cellLon;
        final cellMaxLon = cellMinLon + cellLon;

        // Find observations in this cell
        final cellObservations = observations.where((obs) {
          final lat = obs.location.position.latitude;
          final lon = obs.location.position.longitude;
          return lat >= cellMinLat &&
              lat < cellMaxLat &&
              lon >= cellMinLon &&
              lon < cellMaxLon;
        }).toList();

        if (cellObservations.isNotEmpty) {
          // Calculate intensity
          double intensity = 0;
          double avgDepth = 0;

          for (final obs in cellObservations) {
            if (obs.fishActivity != null) {
              intensity +=
                  obs.fishActivity!.catchRate == 'High' ? 0.8 : 0.5;
            }
            if (obs.waterColumn != null) {
              avgDepth += obs.waterColumn!.thermoclineDepthFt;
            }
          }

          intensity = (intensity / cellObservations.length).clamp(0.0, 1.0);
          avgDepth = avgDepth / cellObservations.length;

          final cellCenterLat = cellMinLat + cellLat / 2;
          final cellCenterLon = cellMinLon + cellLon / 2;

          // Store heat map data
          final heatData = FishHeatMapData(
            id: 'heatmap_${species}_${i}_${j}_${DateTime.now().millisecondsSinceEpoch}',
            latitude: cellCenterLat,
            longitude: cellCenterLon,
            species: species,
            intensity: intensity,
            depth: avgDepth,
            timestamp: DateTime.now(),
          );

          database.storeHeatMapData(heatData);
        }
      }
    }

    if (kDebugMode) {
      print('[MapIntelligenceAgent] Generated heat map for $species');
    }
  }

  /// Get current catch clusters
  List<CatchCluster> getCatchClusters(String? species) {
    final reports = species == null
        ? database.captainReports.values.toList()
        : database.getCaptainReportsBySpecies(species);

    if (reports.isEmpty) return [];

    // Group reports by location
    final locationGroups = <String, List<CaptainReport>>{};
    for (final report in reports) {
      if (!locationGroups.containsKey(report.location)) {
        locationGroups[report.location] = [];
      }
      locationGroups[report.location]!.add(report);
    }

    // Create clusters
    return locationGroups.entries
        .map(
          (e) => CatchCluster(
            location: e.key,
            catchCount: e.value.fold(0, (sum, r) => sum + r.catchCount),
            reportCount: e.value.length,
            avgDepth:
                e.value.map((r) => r.depth).reduce((a, b) => a + b) /
                    e.value.length,
            species: species ?? 'All',
          ),
        )
        .toList();
  }

  /// Get environmental overlay data
  Map<String, dynamic> getEnvironmentalOverlay() {
    final recent = database.getRecentEnvironmental(24);

    if (recent.isEmpty) {
      return {
        'temperature': null,
        'windSpeed': null,
        'windDirection': null,
        'waveHeight': null,
      };
    }

    // Average recent conditions
    final avgTemp = recent.map((s) => s.temperature).reduce((a, b) => a + b) /
        recent.length;
    final avgWind = recent.map((s) => s.windSpeed).reduce((a, b) => a + b) /
        recent.length;
    final avgWaves = recent.map((s) => s.waveHeight).reduce((a, b) => a + b) /
        recent.length;

    // Most common wind direction
    final directions = <String, int>{};
    for (final snapshot in recent) {
      directions[snapshot.windDirection] =
          (directions[snapshot.windDirection] ?? 0) + 1;
    }
    final windDir = directions.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return {
      'temperature': avgTemp,
      'windSpeed': avgWind,
      'windDirection': windDir,
      'waveHeight': avgWaves,
    };
  }

  /// Get bait movement visualization data
  List<BaitMovementPoint> getBaitMovement() {
    final data = <BaitMovementPoint>[];

    // Collect all bait-related observations
    final observations = database.observations.values.where((obs) {
      return obs.forage != null;
    }).toList();

    for (final obs in observations) {
      final forage = obs.forage!;
      data.add(
        BaitMovementPoint(
          latitude: obs.location.position.latitude,
          longitude: obs.location.position.longitude,
          baitType: forage.baitSpecies.isNotEmpty
              ? forage.baitSpecies.first
              : 'Unknown',
          concentration: forage.concentrationScore,
          depth: forage.baitDepthFt,
          timestamp: obs.observedAt,
        ),
      );
    }

    return data;
  }

  /// Get fish movement visualization data
  List<FishMovementPoint> getFishMovement() {
    final data = <FishMovementPoint>[];

    final observations = database.observations.values.where((obs) {
      return obs.fishActivity != null;
    }).toList();

    for (final obs in observations) {
      final activity = obs.fishActivity!;
      for (final signal in activity.speciesSignals) {
        data.add(
          FishMovementPoint(
            latitude: obs.location.position.latitude,
            longitude: obs.location.position.longitude,
            species: signal.species,
            presenceScore: signal.presenceScore,
            depth: activity.presentationDepthFt,
            timestamp: obs.observedAt,
          ),
        );
      }
    }

    return data;
  }

  /// Get weather overlay for visualization
  WeatherOverlay getWeatherOverlay() {
    final recent = database.getRecentEnvironmental(12);

    if (recent.isEmpty) {
      return const WeatherOverlay(
        windVectors: [],
        stormCells: [],
      );
    }

    final latest = recent.last;

    // Create wind vectors
    final windVectors = <WindVector>[];
    const gridSpacing = 0.5; // degrees

    for (double lat = 42.3; lat < 48.3; lat += gridSpacing) {
      for (double lon = -88.0; lon < -85.0; lon += gridSpacing) {
        windVectors.add(
          WindVector(
            latitude: lat,
            longitude: lon,
            speed: latest.windSpeed,
            direction: latest.windDirection,
          ),
        );
      }
    }

    // Storm cells (simplified - in production would use weather data)
    final stormCells = <StormCell>[];

    return WeatherOverlay(
      windVectors: windVectors,
      stormCells: stormCells,
    );
  }

  /// Clear heat maps
  void clearHeatMaps() {
    // In a real implementation, would clear from database
    if (kDebugMode) {
      print('[MapIntelligenceAgent] Cleared heat maps');
    }
  }
}

/// Catch cluster for visualization
class CatchCluster {
  const CatchCluster({
    required this.location,
    required this.catchCount,
    required this.reportCount,
    required this.avgDepth,
    required this.species,
  });

  final String location;
  final int catchCount;
  final int reportCount;
  final double avgDepth;
  final String species;

  double get intensity => (catchCount / 100).clamp(0.0, 1.0);
}

/// Bait movement data point
class BaitMovementPoint {
  const BaitMovementPoint({
    required this.latitude,
    required this.longitude,
    required this.baitType,
    required this.concentration,
    required this.depth,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final String baitType;
  final double concentration;
  final double depth;
  final DateTime timestamp;
}

/// Fish movement data point
class FishMovementPoint {
  const FishMovementPoint({
    required this.latitude,
    required this.longitude,
    required this.species,
    required this.presenceScore,
    required this.depth,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final String species;
  final double presenceScore;
  final double depth;
  final DateTime timestamp;
}

/// Wind vector for weather visualization
class WindVector {
  const WindVector({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.direction,
  });

  final double latitude;
  final double longitude;
  final double speed;
  final String direction;
}

/// Storm cell for weather visualization
class StormCell {
  const StormCell({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.radius,
  });

  final double latitude;
  final double longitude;
  final double intensity; // 0.0 to 1.0
  final double radius; // in nautical miles
}

/// Complete weather overlay
class WeatherOverlay {
  const WeatherOverlay({
    required this.windVectors,
    required this.stormCells,
  });

  final List<WindVector> windVectors;
  final List<StormCell> stormCells;
}
