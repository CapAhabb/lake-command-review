class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class ObservationLocation {
  const ObservationLocation({
    required this.port,
    required this.areaLabel,
    required this.position,
  });

  final String port;
  final String areaLabel;
  final GeoPoint position;
}

class TripContextCluster {
  const TripContextCluster({
    required this.targetSpecies,
    required this.month,
    required this.timeOfDay,
  });

  final String targetSpecies;
  final int month;
  final String timeOfDay;
}

class SurfaceConditionsCluster {
  const SurfaceConditionsCluster({
    required this.surfaceTempF,
    required this.windSpeedKt,
    required this.windDirection,
    required this.waveHeightFt,
    required this.weatherPattern,
  });

  final double surfaceTempF;
  final double windSpeedKt;
  final String windDirection;
  final double waveHeightFt;
  final String weatherPattern;
}

class WaterColumnCluster {
  const WaterColumnCluster({
    required this.thermoclineDepthFt,
    required this.tempAtDepthF,
    required this.clarity,
    required this.depthBandLabel,
  });

  final double thermoclineDepthFt;
  final double tempAtDepthF;
  final String clarity;
  final String depthBandLabel;
}

class CurrentConditionsCluster {
  const CurrentConditionsCluster({
    required this.speedKt,
    required this.direction,
    required this.depthFt,
  });

  final double speedKt;
  final String direction;
  final double depthFt;
}

class ForageCluster {
  const ForageCluster({
    required this.concentrationScore,
    required this.baitSpecies,
    required this.baitDepthFt,
    required this.distributionNote,
  });

  final double concentrationScore;
  final List<String> baitSpecies;
  final double baitDepthFt;
  final String distributionNote;
}

class SpeciesSignal {
  const SpeciesSignal({
    required this.species,
    required this.presenceScore,
    required this.targetabilityScore,
    required this.weightPotentialScore,
    required this.note,
  });

  final String species;
  final double presenceScore;
  final double targetabilityScore;
  final double weightPotentialScore;
  final String note;
}

class FishActivityCluster {
  const FishActivityCluster({
    required this.catchRate,
    required this.bestWindow,
    required this.presentationDepthFt,
    required this.speciesSignals,
  });

  final String catchRate;
  final String bestWindow;
  final double presentationDepthFt;
  final List<SpeciesSignal> speciesSignals;
}

class PresentationCluster {
  const PresentationCluster({
    required this.trollSpeedKt,
    required this.heading,
    required this.lures,
    required this.colorNotes,
  });

  final double trollSpeedKt;
  final String heading;
  final List<String> lures;
  final List<String> colorNotes;
}

class ConfidenceMetadataCluster {
  const ConfidenceMetadataCluster({
    required this.sourceCredibility,
    required this.freshnessHours,
    required this.measuredDataRatio,
    required this.notes,
  });

  final double sourceCredibility;
  final double freshnessHours;
  final double measuredDataRatio;
  final List<String> notes;
}

class ObservationEnvelope {
  const ObservationEnvelope({
    required this.id,
    required this.sourceName,
    required this.sourceType,
    required this.observedAt,
    required this.location,
    this.tripContext,
    this.surfaceConditions,
    this.waterColumn,
    this.currents,
    this.forage,
    this.fishActivity,
    this.presentation,
    this.confidenceMetadata,
  });

  final String id;
  final String sourceName;
  final String sourceType;
  final DateTime observedAt;
  final ObservationLocation location;
  final TripContextCluster? tripContext;
  final SurfaceConditionsCluster? surfaceConditions;
  final WaterColumnCluster? waterColumn;
  final CurrentConditionsCluster? currents;
  final ForageCluster? forage;
  final FishActivityCluster? fishActivity;
  final PresentationCluster? presentation;
  final ConfidenceMetadataCluster? confidenceMetadata;
}

class HistoricalTournamentResult {
  const HistoricalTournamentResult({
    required this.id,
    required this.eventName,
    required this.observedAt,
    required this.port,
    required this.areaLabel,
    required this.teamCount,
    required this.totalWeightLb,
    required this.bigFishLb,
    required this.speciesWeightsLb,
    required this.notes,
  });

  final String id;
  final String eventName;
  final DateTime observedAt;
  final String port;
  final String areaLabel;
  final int teamCount;
  final double totalWeightLb;
  final double bigFishLb;
  final Map<String, double> speciesWeightsLb;
  final String notes;
}

class ScenarioRequest {
  const ScenarioRequest({
    required this.targetSpecies,
    required this.month,
    required this.timeOfDay,
    required this.waterClarity,
    required this.waterDepthFt,
    required this.surfaceTempF,
    required this.thermoclineDepthFt,
    required this.currentSpeedKt,
    required this.baitLevel,
    required this.reportStrength,
    required this.weatherPattern,
  });

  final String targetSpecies;
  final int month;
  final String timeOfDay;
  final String waterClarity;
  final double waterDepthFt;
  final double surfaceTempF;
  final double thermoclineDepthFt;
  final double currentSpeedKt;
  final double baitLevel;
  final double reportStrength;
  final String weatherPattern;
}

class AggregatedSpeciesOutlook {
  const AggregatedSpeciesOutlook({
    required this.species,
    required this.presenceScore,
    required this.targetabilityScore,
    required this.weightPotentialScore,
    required this.summary,
  });

  final String species;
  final double presenceScore;
  final double targetabilityScore;
  final double weightPotentialScore;
  final String summary;
}

class AggregatedScenario {
  const AggregatedScenario({
    required this.targetSpecies,
    required this.primaryPort,
    required this.areaLabel,
    required this.summary,
    required this.presenceScore,
    required this.concentrationScore,
    required this.targetabilityScore,
    required this.weightPotentialScore,
    required this.probabilityScore,
    required this.primeTargetSpecies,
    required this.fallbackSpecies,
    required this.averageSurfaceTempF,
    required this.averageThermoclineDepthFt,
    required this.averageCurrentSpeedKt,
    required this.averageBaitScore,
    required this.observationCount,
    required this.tournamentCount,
    required this.evidence,
    required this.outlooks,
  });

  final String targetSpecies;
  final String primaryPort;
  final String areaLabel;
  final String summary;
  final int presenceScore;
  final int concentrationScore;
  final int targetabilityScore;
  final int weightPotentialScore;
  final int probabilityScore;
  final String primeTargetSpecies;
  final String fallbackSpecies;
  final double averageSurfaceTempF;
  final double averageThermoclineDepthFt;
  final double averageCurrentSpeedKt;
  final double averageBaitScore;
  final int observationCount;
  final int tournamentCount;
  final List<String> evidence;
  final List<AggregatedSpeciesOutlook> outlooks;
}
