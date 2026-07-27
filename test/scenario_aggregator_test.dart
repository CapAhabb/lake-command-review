import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/models/observation_models.dart';
import 'package:starter_app/services/scenario_aggregator.dart';

void main() {
  late ScenarioAggregator aggregator;

  setUp(() {
    aggregator = const ScenarioAggregator();
  });

  group('ScenarioAggregator._average', () {
    test('returns 0 for empty list', () {
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.averageBaitScore, 0);
      expect(result.averageThermoclineDepthFt, 0);
      expect(result.averageCurrentSpeedKt, 0);
    });

    test('returns average for single value', () {
      final observation = _createObservation(
        forage: const ForageCluster(
          concentrationScore: 7.0,
          baitSpecies: <String>['Alewife'],
          baitDepthFt: 40,
          distributionNote: 'Test',
        ),
      );
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.averageBaitScore, 7.0);
    });

    test('returns average for multiple values', () {
      final observations = <ObservationEnvelope>[
        _createObservation(
          forage: const ForageCluster(
            concentrationScore: 6.0,
            baitSpecies: <String>['Alewife'],
            baitDepthFt: 40,
            distributionNote: 'Test',
          ),
        ),
        _createObservation(
          forage: const ForageCluster(
            concentrationScore: 8.0,
            baitSpecies: <String>['Smelt'],
            baitDepthFt: 45,
            distributionNote: 'Test 2',
          ),
        ),
      ];
      final result = aggregator.build(
        request: _createRequest(),
        observations: observations,
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.averageBaitScore, 7.0);
    });
  });

  group('ScenarioAggregator month filtering', () {
    test('filters observations by month when matches exist', () {
      final julyObs = _createObservationWithMonth(7);
      final augustObs = _createObservationWithMonth(8);
      final result = aggregator.build(
        request: _createRequest(month: 7),
        observations: <ObservationEnvelope>[julyObs, augustObs],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.observationCount, 1);
    });

    test('uses all observations when no month matches', () {
      final julyObs = _createObservationWithMonth(7);
      final result = aggregator.build(
        request: _createRequest(month: 12),
        observations: <ObservationEnvelope>[julyObs],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.observationCount, 1);
    });
  });

  group('ScenarioAggregator species outlooks', () {
    test('builds species outlooks from fish activity signals', () {
      final observation = _createObservation(
        fishActivity: const FishActivityCluster(
          catchRate: '5 for 8',
          bestWindow: '06:00-07:30',
          presentationDepthFt: 48,
          speciesSignals: <SpeciesSignal>[
            SpeciesSignal(
              species: 'King Salmon',
              presenceScore: 8.5,
              targetabilityScore: 8.0,
              weightPotentialScore: 9.0,
              note: 'Strong signal',
            ),
          ],
        ),
      );
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.outlooks, isNotEmpty);
      expect(result.outlooks.first.species, 'King Salmon');
    });

    test('returns fallback outlook when no fish activity exists', () {
      final observation = _createObservation();
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.outlooks, isNotEmpty);
      expect(result.outlooks.first.species, 'King Salmon');
    });
  });

  group('ScenarioAggregator score calculation', () {
    test('calculates probability score from component scores', () {
      final observation = _createObservation(
        forage: const ForageCluster(
          concentrationScore: 7.0,
          baitSpecies: <String>['Alewife'],
          baitDepthFt: 40,
          distributionNote: 'Test',
        ),
        waterColumn: const WaterColumnCluster(
          thermoclineDepthFt: 45,
          tempAtDepthF: 48,
          clarity: 'Mixed green',
          depthBandLabel: '40-55',
        ),
        currents: const CurrentConditionsCluster(
          speedKt: 1.2,
          direction: 'NE',
          depthFt: 50,
        ),
        confidenceMetadata: const ConfidenceMetadataCluster(
          sourceCredibility: 8.0,
          freshnessHours: 5,
          measuredDataRatio: 0.8,
          notes: <String>['Test note'],
        ),
      );
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.probabilityScore, greaterThan(0));
      expect(result.presenceScore, greaterThan(0));
      expect(result.concentrationScore, greaterThan(0));
      expect(result.targetabilityScore, greaterThan(0));
      expect(result.weightPotentialScore, greaterThan(0));
    });
  });

  group('ScenarioAggregator location', () {
    test('uses observation port when available', () {
      final observation = _createObservation(
        location: const ObservationLocation(
          port: 'Muskegon',
          areaLabel: 'Muskegon shelf',
          position: GeoPoint(latitude: 43.2, longitude: -86.3),
        ),
      );
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.primaryPort, 'Muskegon');
      expect(result.areaLabel, 'Muskegon shelf');
    });
  });

  group('ScenarioAggregator evidence', () {
    test('generates evidence list with observation count', () {
      final observation = _createObservation(
        forage: const ForageCluster(
          concentrationScore: 8.0,
          baitSpecies: <String>['Alewife'],
          baitDepthFt: 40,
          distributionNote: 'Test',
        ),
      );
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.evidence, isNotEmpty);
      expect(result.evidence.first, contains('1 observations'));
    });
  });

  group('ScenarioAggregator tournament results', () {
    test('filters tournaments by month', () {
      final julyTournament = _createTournament(month: 7);
      final augustTournament = _createTournament(month: 8);
      final result = aggregator.build(
        request: _createRequest(month: 7),
        observations: <ObservationEnvelope>[],
        tournamentResults: <HistoricalTournamentResult>[julyTournament, augustTournament],
      );
      expect(result.tournamentCount, 1);
    });

    test('uses all tournaments when no month matches', () {
      final julyTournament = _createTournament(month: 7);
      final result = aggregator.build(
        request: _createRequest(month: 12),
        observations: <ObservationEnvelope>[],
        tournamentResults: <HistoricalTournamentResult>[julyTournament],
      );
      expect(result.tournamentCount, 1);
    });
  });

  group('ScenarioAggregator prime/fallback species', () {
    test('identifies prime species from outlooks', () {
      final observation = _createObservation(
        fishActivity: const FishActivityCluster(
          catchRate: '5 for 8',
          bestWindow: '06:00-07:30',
          presentationDepthFt: 48,
          speciesSignals: <SpeciesSignal>[
            SpeciesSignal(
              species: 'King Salmon',
              presenceScore: 8.0,
              targetabilityScore: 8.0,
              weightPotentialScore: 9.0,
              note: 'Best species',
            ),
            SpeciesSignal(
              species: 'Steelhead',
              presenceScore: 6.0,
              targetabilityScore: 7.0,
              weightPotentialScore: 5.0,
              note: 'Secondary',
            ),
          ],
        ),
      );
      final result = aggregator.build(
        request: _createRequest(),
        observations: <ObservationEnvelope>[observation],
        tournamentResults: <HistoricalTournamentResult>[],
      );
      expect(result.primeTargetSpecies, 'King Salmon');
      expect(result.fallbackSpecies, isNotEmpty);
    });
  });
}

ScenarioRequest _createRequest({
  String targetSpecies = 'King Salmon',
  int month = 7,
}) {
  return ScenarioRequest(
    targetSpecies: targetSpecies,
    month: month,
    timeOfDay: 'First light',
    waterClarity: 'Mixed green',
    waterDepthFt: 80,
    surfaceTempF: 54,
    thermoclineDepthFt: 46,
    currentSpeedKt: 1.2,
    baitLevel: 7,
    reportStrength: 7,
    weatherPattern: 'Stable',
  );
}

ObservationEnvelope _createObservation({
  ObservationLocation? location,
  ForageCluster? forage,
  FishActivityCluster? fishActivity,
  WaterColumnCluster? waterColumn,
  CurrentConditionsCluster? currents,
  ConfidenceMetadataCluster? confidenceMetadata,
}) {
  return ObservationEnvelope(
    id: 'obs-test-001',
    sourceName: 'Test Source',
    sourceType: 'test',
    observedAt: DateTime(2026, 7, 14),
    location: location ??
        const ObservationLocation(
          port: 'South Haven',
          areaLabel: 'Test area',
          position: GeoPoint(latitude: 42.4, longitude: -86.35),
        ),
    forage: forage,
    fishActivity: fishActivity,
    waterColumn: waterColumn,
    currents: currents,
    confidenceMetadata: confidenceMetadata,
  );
}

ObservationEnvelope _createObservationWithMonth(int month) {
  return ObservationEnvelope(
    id: 'obs-month-$month',
    sourceName: 'Test',
    sourceType: 'test',
    observedAt: DateTime(2026, month, 14),
    location: const ObservationLocation(
      port: 'Test Port',
      areaLabel: 'Test Area',
      position: GeoPoint(latitude: 42.4, longitude: -86.35),
    ),
    tripContext: TripContextCluster(
      targetSpecies: 'King Salmon',
      month: month,
      timeOfDay: 'Morning',
    ),
  );
}

HistoricalTournamentResult _createTournament({
  required int month,
}) {
  return HistoricalTournamentResult(
    id: 'tour-test-$month',
    eventName: 'Test Tournament',
    observedAt: DateTime(2024, month, 15),
    port: 'Test Port',
    areaLabel: 'Test Area',
    teamCount: 30,
    totalWeightLb: 65.0,
    bigFishLb: 20.0,
    speciesWeightsLb: const <String, double>{
      'King Salmon': 35.0,
      'Lake Trout': 20.0,
      'Steelhead': 10.0,
    },
    notes: 'Test tournament notes',
  );
}