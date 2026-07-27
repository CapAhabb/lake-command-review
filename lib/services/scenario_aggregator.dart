import '../models/observation_models.dart';

class ScenarioAggregator {
  const ScenarioAggregator();

  AggregatedScenario build({
    required ScenarioRequest request,
    required List<ObservationEnvelope> observations,
    required List<HistoricalTournamentResult> tournamentResults,
  }) {
    final List<ObservationEnvelope> monthMatches = observations
        .where(
          (ObservationEnvelope observation) =>
              observation.tripContext == null ||
              observation.tripContext!.month == request.month,
        )
        .toList();
    final List<ObservationEnvelope> activeObservations = monthMatches.isEmpty
        ? observations
        : monthMatches;
    final List<HistoricalTournamentResult> monthTournaments = tournamentResults
        .where(
          (HistoricalTournamentResult result) =>
              result.observedAt.month == request.month,
        )
        .toList();
    final List<HistoricalTournamentResult> activeTournaments =
        monthTournaments.isEmpty ? tournamentResults : monthTournaments;

    final List<SpeciesSignal> speciesSignals = activeObservations
        .where(
          (ObservationEnvelope observation) => observation.fishActivity != null,
        )
        .expand(
          (ObservationEnvelope observation) =>
              observation.fishActivity!.speciesSignals,
        )
        .toList();

    final Map<String, List<SpeciesSignal>> signalsBySpecies =
        <String, List<SpeciesSignal>>{};
    for (final SpeciesSignal signal in speciesSignals) {
      signalsBySpecies
          .putIfAbsent(signal.species, () => <SpeciesSignal>[])
          .add(signal);
    }

    final double averageSurfaceTempF = _average(
      activeObservations
          .where(
            (ObservationEnvelope observation) =>
                observation.surfaceConditions != null,
          )
          .map(
            (ObservationEnvelope observation) =>
                observation.surfaceConditions!.surfaceTempF,
          )
          .toList(),
    );
    final double averageThermoclineDepthFt = _average(
      activeObservations
          .where(
            (ObservationEnvelope observation) =>
                observation.waterColumn != null,
          )
          .map(
            (ObservationEnvelope observation) =>
                observation.waterColumn!.thermoclineDepthFt,
          )
          .toList(),
    );
    final double averageCurrentSpeedKt = _average(
      activeObservations
          .where(
            (ObservationEnvelope observation) => observation.currents != null,
          )
          .map(
            (ObservationEnvelope observation) => observation.currents!.speedKt,
          )
          .toList(),
    );
    final double averageBaitScore = _average(
      activeObservations
          .where(
            (ObservationEnvelope observation) => observation.forage != null,
          )
          .map(
            (ObservationEnvelope observation) =>
                observation.forage!.concentrationScore,
          )
          .toList(),
    );
    final double sourceCredibility = _average(
      activeObservations
          .where(
            (ObservationEnvelope observation) =>
                observation.confidenceMetadata != null,
          )
          .map(
            (ObservationEnvelope observation) =>
                observation.confidenceMetadata!.sourceCredibility,
          )
          .toList(),
    );
    final double measuredRatio = _average(
      activeObservations
          .where(
            (ObservationEnvelope observation) =>
                observation.confidenceMetadata != null,
          )
          .map(
            (ObservationEnvelope observation) =>
                observation.confidenceMetadata!.measuredDataRatio * 10,
          )
          .toList(),
    );

    final List<AggregatedSpeciesOutlook> outlooks =
        signalsBySpecies.entries
            .map(
              (MapEntry<String, List<SpeciesSignal>> entry) =>
                  _buildSpeciesOutlook(
                    species: entry.key,
                    signals: entry.value,
                    tournamentResults: activeTournaments,
                  ),
            )
            .toList()
          ..sort(
            (AggregatedSpeciesOutlook a, AggregatedSpeciesOutlook b) =>
                b.weightPotentialScore.compareTo(a.weightPotentialScore),
          );

    final AggregatedSpeciesOutlook targetOutlook = outlooks.firstWhere(
      (AggregatedSpeciesOutlook outlook) =>
          outlook.species == request.targetSpecies,
      orElse: () => AggregatedSpeciesOutlook(
        species: request.targetSpecies,
        presenceScore: _normalizeScore(request.baitLevel + 1.5),
        targetabilityScore: _normalizeScore(request.reportStrength + 1.0),
        weightPotentialScore: _normalizeScore(
          request.waterDepthFt >= 100 ? 6.5 : 5.0,
        ),
        summary:
            'No historical species cluster yet, leaning on manual scenario inputs.',
      ),
    );

    final AggregatedSpeciesOutlook primeOutlook = outlooks.isEmpty
        ? targetOutlook
        : outlooks.first;
    final AggregatedSpeciesOutlook fallbackOutlook = outlooks
        .where(
          (AggregatedSpeciesOutlook outlook) =>
              outlook.species != primeOutlook.species,
        )
        .cast<AggregatedSpeciesOutlook?>()
        .firstWhere(
          (AggregatedSpeciesOutlook? outlook) => outlook != null,
          orElse: () => targetOutlook,
        )!;

    final int presenceScore = _toIntScore(
      targetOutlook.presenceScore * 0.55 +
          averageBaitScore * 4.2 +
          request.reportStrength * 2.6,
    );
    final int concentrationScore = _toIntScore(
      averageBaitScore * 4.8 +
          _thermoclineBonus(
            request.thermoclineDepthFt,
            averageThermoclineDepthFt,
          ) +
          _tempWindowBonus(request.surfaceTempF, averageSurfaceTempF) +
          targetOutlook.presenceScore * 0.8,
    );
    final int targetabilityScore = _toIntScore(
      targetOutlook.targetabilityScore * 0.7 +
          request.reportStrength * 4.1 +
          _currentControlBonus(request.currentSpeedKt, averageCurrentSpeedKt) +
          _clarityBonus(request.waterClarity),
    );
    final int weightPotentialScore = _toIntScore(
      targetOutlook.weightPotentialScore * 0.8 +
          _tournamentWeightBonus(request.targetSpecies, activeTournaments) +
          (request.waterDepthFt >= 100 ? 8 : 4),
    );
    final int probabilityScore = _toIntScore(
      presenceScore * 0.24 +
          concentrationScore * 0.32 +
          targetabilityScore * 0.22 +
          weightPotentialScore * 0.14 +
          sourceCredibility * 3 +
          measuredRatio * 1.6,
    );

    final String primaryPort = activeObservations.isEmpty
        ? 'South Haven'
        : activeObservations.first.location.port;
    final String areaLabel = activeObservations.isEmpty
        ? 'Lake Michigan offshore lane'
        : activeObservations.first.location.areaLabel;

    final List<String> evidence = <String>[
      'Mock fusion layer pulled ${activeObservations.length} observations and ${activeTournaments.length} tournament results into one scenario.',
      'Average bait score is ${averageBaitScore.toStringAsFixed(1)}/10 with a thermocline centered near ${averageThermoclineDepthFt.toStringAsFixed(0)} ft.',
      '${targetOutlook.species} show a ${targetOutlook.presenceScore.toStringAsFixed(1)}/10 presence signal and ${targetOutlook.weightPotentialScore.toStringAsFixed(1)}/10 weight potential.',
      '${primeOutlook.species} is the best pure weight species in the mock history; ${fallbackOutlook.species} is the strongest fallback if the primary lane thins out.',
      'Measured-data ratio is ${measuredRatio.toStringAsFixed(1)}/10, so this preview already distinguishes hard data from report-driven inputs.',
    ];

    final String summary =
        'The fused mock model sees ${targetOutlook.species} as a live concentration play near ${averageThermoclineDepthFt.toStringAsFixed(0)} ft, with ${fallbackOutlook.species} holding the best fallback weight plan.';

    return AggregatedScenario(
      targetSpecies: request.targetSpecies,
      primaryPort: primaryPort,
      areaLabel: areaLabel,
      summary: summary,
      presenceScore: presenceScore,
      concentrationScore: concentrationScore,
      targetabilityScore: targetabilityScore,
      weightPotentialScore: weightPotentialScore,
      probabilityScore: probabilityScore,
      primeTargetSpecies: primeOutlook.species,
      fallbackSpecies: fallbackOutlook.species,
      averageSurfaceTempF: averageSurfaceTempF,
      averageThermoclineDepthFt: averageThermoclineDepthFt,
      averageCurrentSpeedKt: averageCurrentSpeedKt,
      averageBaitScore: averageBaitScore,
      observationCount: activeObservations.length,
      tournamentCount: activeTournaments.length,
      evidence: evidence,
      outlooks: outlooks.isEmpty
          ? <AggregatedSpeciesOutlook>[targetOutlook]
          : outlooks,
    );
  }

  AggregatedSpeciesOutlook _buildSpeciesOutlook({
    required String species,
    required List<SpeciesSignal> signals,
    required List<HistoricalTournamentResult> tournamentResults,
  }) {
    final double presenceScore = _average(
      signals.map((SpeciesSignal signal) => signal.presenceScore).toList(),
    );
    final double targetabilityScore = _average(
      signals.map((SpeciesSignal signal) => signal.targetabilityScore).toList(),
    );
    final double signalWeightPotential = _average(
      signals
          .map((SpeciesSignal signal) => signal.weightPotentialScore)
          .toList(),
    );
    final double tournamentWeight = _averageTournamentShare(
      species,
      tournamentResults,
    );
    final double weightPotentialScore = _normalizeScore(
      signalWeightPotential * 0.65 + tournamentWeight * 0.35,
    );
    final String dominantNote = signals.first.note;

    return AggregatedSpeciesOutlook(
      species: species,
      presenceScore: _normalizeScore(presenceScore),
      targetabilityScore: _normalizeScore(targetabilityScore),
      weightPotentialScore: weightPotentialScore,
      summary:
          '$species score ${presenceScore.toStringAsFixed(1)}/10 for presence with tournament-weight share ${tournamentWeight.toStringAsFixed(1)}/10. $dominantNote',
    );
  }

  double _averageTournamentShare(
    String species,
    List<HistoricalTournamentResult> tournamentResults,
  ) {
    if (tournamentResults.isEmpty) {
      return 5;
    }

    final List<double> shares = tournamentResults.map((
      HistoricalTournamentResult result,
    ) {
      final double speciesWeight = result.speciesWeightsLb[species] ?? 0;
      if (result.totalWeightLb <= 0) {
        return 0.0;
      }
      return (speciesWeight / result.totalWeightLb) * 10;
    }).toList();

    return _average(shares);
  }

  double _tournamentWeightBonus(
    String species,
    List<HistoricalTournamentResult> tournamentResults,
  ) {
    return _averageTournamentShare(species, tournamentResults) * 3.6;
  }

  double _thermoclineBonus(double requested, double averageObserved) {
    final double distance = (requested - averageObserved).abs();
    if (distance <= 6) {
      return 16;
    }
    if (distance <= 12) {
      return 11;
    }
    return 5;
  }

  double _tempWindowBonus(double requested, double averageObserved) {
    final double distance = (requested - averageObserved).abs();
    if (distance <= 3) {
      return 14;
    }
    if (distance <= 6) {
      return 8;
    }
    return 3;
  }

  double _currentControlBonus(double requested, double averageObserved) {
    final double distance = (requested - averageObserved).abs();
    if (requested <= 1.6 && distance <= 0.4) {
      return 14;
    }
    if (requested <= 2.0) {
      return 9;
    }
    return 4;
  }

  double _clarityBonus(String clarity) {
    switch (clarity) {
      case 'Mixed green':
        return 12;
      case 'Clear':
        return 10;
      case 'Muddy / stained':
        return 8;
      case 'Ultra clear':
        return 6;
      default:
        return 7;
    }
  }

  double _normalizeScore(double score) {
    return score.clamp(0, 10).toDouble();
  }

  int _toIntScore(double score) {
    return score.round().clamp(0, 99);
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    final double total = values.reduce((double a, double b) => a + b);
    return total / values.length;
  }
}
