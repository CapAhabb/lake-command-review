import '../models/observation_models.dart';

class MockDataRepository {
  const MockDataRepository();

  List<ObservationEnvelope> lakeMichiganObservations() {
    return <ObservationEnvelope>[
      ObservationEnvelope(
        id: 'obs-noaa-001',
        sourceName: 'NOAA Offshore Blend',
        sourceType: 'forecast',
        observedAt: DateTime(2026, 7, 14, 4, 30),
        location: const ObservationLocation(
          port: 'South Haven',
          areaLabel: 'South Haven shelf edge',
          position: GeoPoint(latitude: 42.401, longitude: -86.355),
        ),
        tripContext: const TripContextCluster(
          targetSpecies: 'King Salmon',
          month: 7,
          timeOfDay: 'First light',
        ),
        surfaceConditions: const SurfaceConditionsCluster(
          surfaceTempF: 54,
          windSpeedKt: 13,
          windDirection: 'SW',
          waveHeightFt: 2.1,
          weatherPattern: 'Stable',
        ),
        waterColumn: const WaterColumnCluster(
          thermoclineDepthFt: 46,
          tempAtDepthF: 48,
          clarity: 'Mixed green',
          depthBandLabel: '38-58 down',
        ),
        currents: const CurrentConditionsCluster(
          speedKt: 1.1,
          direction: 'NE set',
          depthFt: 50,
        ),
        confidenceMetadata: const ConfidenceMetadataCluster(
          sourceCredibility: 8.8,
          freshnessHours: 4,
          measuredDataRatio: 0.8,
          notes: <String>['Modeled blend with buoy alignment.'],
        ),
      ),
      ObservationEnvelope(
        id: 'obs-capt-014',
        sourceName: 'Captain Log Cluster',
        sourceType: 'captain-report',
        observedAt: DateTime(2026, 7, 13, 20, 10),
        location: const ObservationLocation(
          port: 'South Haven',
          areaLabel: 'Mid-shelf bait edge',
          position: GeoPoint(latitude: 42.469, longitude: -86.412),
        ),
        forage: const ForageCluster(
          concentrationScore: 8.4,
          baitSpecies: <String>['Alewife', 'Smelt'],
          baitDepthFt: 42,
          distributionNote:
              'Dense arcs on the west edge of the break with scattered high bait.',
        ),
        fishActivity: const FishActivityCluster(
          catchRate: '7 for 11',
          bestWindow: '05:35-07:20',
          presentationDepthFt: 48,
          speciesSignals: <SpeciesSignal>[
            SpeciesSignal(
              species: 'King Salmon',
              presenceScore: 9.0,
              targetabilityScore: 8.4,
              weightPotentialScore: 8.8,
              note: 'Adult kings centered just below the break.',
            ),
            SpeciesSignal(
              species: 'Steelhead',
              presenceScore: 6.8,
              targetabilityScore: 7.4,
              weightPotentialScore: 5.6,
              note: 'Scattered high fish on the warm edge.',
            ),
            SpeciesSignal(
              species: 'Lake Trout',
              presenceScore: 7.1,
              targetabilityScore: 8.3,
              weightPotentialScore: 7.0,
              note: 'Bottom fish available if the king lane dies.',
            ),
          ],
        ),
        presentation: const PresentationCluster(
          trollSpeedKt: 2.4,
          heading: 'West troll, slight north angle',
          lures: <String>['Green glow paddle', 'Meat rig', 'White crush spoon'],
          colorNotes: <String>['Glow first pass, chrome once sun clears haze.'],
        ),
        confidenceMetadata: const ConfidenceMetadataCluster(
          sourceCredibility: 7.9,
          freshnessHours: 11,
          measuredDataRatio: 0.6,
          notes: <String>[
            'Crowd-supported pattern from three returning crews.',
          ],
        ),
      ),
      ObservationEnvelope(
        id: 'obs-sonar-008',
        sourceName: 'Sonar / Temp Probe Replay',
        sourceType: 'sensor',
        observedAt: DateTime(2026, 7, 13, 6, 5),
        location: const ObservationLocation(
          port: 'South Haven',
          areaLabel: 'West edge contour swing',
          position: GeoPoint(latitude: 42.483, longitude: -86.431),
        ),
        waterColumn: const WaterColumnCluster(
          thermoclineDepthFt: 44,
          tempAtDepthF: 47,
          clarity: 'Mixed green',
          depthBandLabel: '42-55 down',
        ),
        currents: const CurrentConditionsCluster(
          speedKt: 1.3,
          direction: 'North push',
          depthFt: 52,
        ),
        forage: const ForageCluster(
          concentrationScore: 7.8,
          baitSpecies: <String>['Alewife'],
          baitDepthFt: 40,
          distributionNote: 'Tight bait balls stacked over 110-130 FOW.',
        ),
        fishActivity: const FishActivityCluster(
          catchRate: '4 for 6',
          bestWindow: '06:00-07:00',
          presentationDepthFt: 46,
          speciesSignals: <SpeciesSignal>[
            SpeciesSignal(
              species: 'King Salmon',
              presenceScore: 8.7,
              targetabilityScore: 8.0,
              weightPotentialScore: 8.5,
              note: 'Heavier hooks near bait density peaks.',
            ),
            SpeciesSignal(
              species: 'Coho Salmon',
              presenceScore: 5.8,
              targetabilityScore: 6.3,
              weightPotentialScore: 4.9,
              note: 'Support fish on higher lines, not the core weight play.',
            ),
          ],
        ),
        confidenceMetadata: const ConfidenceMetadataCluster(
          sourceCredibility: 8.6,
          freshnessHours: 28,
          measuredDataRatio: 0.9,
          notes: <String>['Probe and sonar replay from prior productive pass.'],
        ),
      ),
    ];
  }

  List<HistoricalTournamentResult> lakeMichiganTournamentResults() {
    return <HistoricalTournamentResult>[
      HistoricalTournamentResult(
        id: 'tour-2024-sh-01',
        eventName: 'South Haven Summer Shootout',
        observedAt: DateTime(2024, 7, 20, 15, 0),
        port: 'South Haven',
        areaLabel: 'South Haven offshore',
        teamCount: 46,
        totalWeightLb: 78.4,
        bigFishLb: 24.1,
        speciesWeightsLb: const <String, double>{
          'King Salmon': 45.6,
          'Lake Trout': 19.8,
          'Steelhead': 8.4,
          'Coho Salmon': 4.6,
        },
        notes:
            'Kings carried the win; lakers filled boxes when mature kings scattered after 0900.',
      ),
      HistoricalTournamentResult(
        id: 'tour-2025-sh-02',
        eventName: 'Harbor to Shelf Invitational',
        observedAt: DateTime(2025, 7, 12, 15, 30),
        port: 'South Haven',
        areaLabel: 'Mid-shelf break',
        teamCount: 38,
        totalWeightLb: 71.2,
        bigFishLb: 22.7,
        speciesWeightsLb: const <String, double>{
          'King Salmon': 39.9,
          'Lake Trout': 18.7,
          'Steelhead': 7.3,
          'Coho Salmon': 5.3,
        },
        notes:
            'Best boxes came from crews who stayed on the bait edge and dropped for lakers after kings slowed.',
      ),
      HistoricalTournamentResult(
        id: 'tour-2025-mst-01',
        eventName: 'Mid-Summer Team Trail',
        observedAt: DateTime(2025, 7, 26, 16, 10),
        port: 'South Haven',
        areaLabel: 'West edge contour swing',
        teamCount: 52,
        totalWeightLb: 83.9,
        bigFishLb: 25.8,
        speciesWeightsLb: const <String, double>{
          'King Salmon': 49.1,
          'Lake Trout': 21.2,
          'Steelhead': 9.1,
          'Coho Salmon': 4.5,
        },
        notes:
            'High-weight boxes were built on adult kings early, with lakers as the weight insurance species.',
      ),
    ];
  }
}
