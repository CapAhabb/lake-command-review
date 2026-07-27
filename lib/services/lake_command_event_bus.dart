import 'package:flutter/foundation.dart';

/// Base class for all Lake Command events
abstract class LakeCommandEvent {
  const LakeCommandEvent();
}

/// Event emitted when a new observation is collected
class ObservationCollectedEvent extends LakeCommandEvent {
  const ObservationCollectedEvent({
    required this.observationId,
    required this.agentName,
    required this.timestamp,
  });

  final String observationId;
  final String agentName;
  final DateTime timestamp;
}

/// Event emitted when environmental data is updated
class EnvironmentalUpdateEvent extends LakeCommandEvent {
  const EnvironmentalUpdateEvent({
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.waveHeight,
    required this.pressure,
    required this.timestamp,
  });

  final double temperature;
  final double windSpeed;
  final String windDirection;
  final double waveHeight;
  final double pressure;
  final DateTime timestamp;
}

/// Event emitted when fish intelligence is updated
class FishIntelligenceUpdateEvent extends LakeCommandEvent {
  const FishIntelligenceUpdateEvent({
    required this.species,
    required this.depthRange,
    required this.confidence,
    required this.timestamp,
  });

  final String species;
  final DepthRange depthRange;
  final double confidence;
  final DateTime timestamp;
}

/// Event emitted when bait intelligence is updated
class BaitIntelligenceUpdateEvent extends LakeCommandEvent {
  const BaitIntelligenceUpdateEvent({
    required this.baitSpecies,
    required this.location,
    required this.concentration,
    required this.timestamp,
  });

  final String baitSpecies;
  final String location;
  final double concentration;
  final DateTime timestamp;
}

/// Event emitted when a captain report is parsed
class CaptainReportParsedEvent extends LakeCommandEvent {
  const CaptainReportParsedEvent({
    required this.reportId,
    required this.species,
    required this.depth,
    required this.lure,
    required this.catchCount,
    required this.timestamp,
  });

  final String reportId;
  final String species;
  final double depth;
  final String lure;
  final int catchCount;
  final DateTime timestamp;
}

/// Event emitted when lure intelligence is updated
class LureIntelligenceUpdateEvent extends LakeCommandEvent {
  const LureIntelligenceUpdateEvent({
    required this.lure,
    required this.color,
    required this.speed,
    required this.successRate,
    required this.timestamp,
  });

  final String lure;
  final String color;
  final double speed;
  final double successRate;
  final DateTime timestamp;
}

/// Event emitted when a prediction is generated
class PredictionGeneratedEvent extends LakeCommandEvent {
  const PredictionGeneratedEvent({
    required this.predictionId,
    required this.targetSpecies,
    required this.recommendedDepth,
    required this.confidence,
    required this.timestamp,
  });

  final String predictionId;
  final String targetSpecies;
  final double recommendedDepth;
  final double confidence;
  final DateTime timestamp;
}

/// Depth range model
class DepthRange {
  const DepthRange({required this.minFeet, required this.maxFeet});

  final double minFeet;
  final double maxFeet;

  @override
  String toString() => 'DepthRange($minFeet-$maxFeet ft)';
}

/// Central event bus for Lake Command agent communication
class LakeCommandEventBus extends ChangeNotifier {
  final List<LakeCommandEvent> _eventHistory = [];

  /// Get the complete event history
  List<LakeCommandEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Emit an event to all listening agents
  void emit(LakeCommandEvent event) {
    _eventHistory.add(event);
    notifyListeners();

    // Print event for debugging
    if (kDebugMode) {
      print('[LakeCommandEventBus] Event emitted: ${event.runtimeType}');
    }
  }

  /// Get events of a specific type
  List<T> getEventsOfType<T extends LakeCommandEvent>() {
    return _eventHistory.whereType<T>().toList();
  }

  /// Get recent events (last N events)
  List<LakeCommandEvent> getRecentEvents(int count) {
    final start = (_eventHistory.length - count).clamp(0, _eventHistory.length);
    return _eventHistory.sublist(start);
  }

  /// Clear event history (for testing or reset)
  void clearHistory() {
    _eventHistory.clear();
    notifyListeners();
  }

  /// Get latest event of a specific type
  T? getLatestEventOfType<T extends LakeCommandEvent>() {
    try {
      return _eventHistory.lastWhere((event) => event is T) as T?;
    } catch (_) {
      return null;
    }
  }
}
