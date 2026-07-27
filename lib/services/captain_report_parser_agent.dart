import 'package:flutter/foundation.dart';
import 'lake_command_event_bus.dart';
import 'lake_command_database.dart';

/// Agent 4 - Captain Report Parser
/// Reads fishing reports and converts them into structured intelligence
class CaptainReportParserAgent {
  CaptainReportParserAgent({
    required this.eventBus,
    required this.database,
  });

  final LakeCommandEventBus eventBus;
  final LakeCommandDatabase database;

  /// Parse a captain report and store structured data
  void parseAndStoreReport({
    required String captainName,
    required String reportText,
    required DateTime reportDate,
  }) {
    // Extract data from report text
    final parsed = _parseReportText(reportText);

    final report = CaptainReport(
      id: 'report_${reportDate.millisecondsSinceEpoch}_${captainName.hashCode}',
      captainName: captainName,
      reportDate: reportDate,
      species: parsed.species,
      depth: parsed.depth,
      speed: parsed.speed,
      lure: parsed.lure,
      color: parsed.color,
      catchCount: parsed.catchCount,
      waterTemp: parsed.waterTemp,
      waterClarity: parsed.waterClarity,
      location: parsed.location,
      confidence: parsed.confidence,
    );

    // Store in database
    database.storeCaptainReport(report);

    // Emit event for other agents
    eventBus.emit(
      CaptainReportParsedEvent(
        reportId: report.id,
        species: report.species,
        depth: report.depth,
        lure: report.lure,
        catchCount: report.catchCount,
        timestamp: reportDate,
      ),
    );

    if (kDebugMode) {
      print(
        '[CaptainReportParserAgent] Parsed report from $captainName: '
        '${report.catchCount} ${report.species} at ${report.depth} ft',
      );
    }
  }

  /// Parse report text and extract structured data
  ParsedCaptainReport _parseReportText(String text) {
    final lowerText = text.toLowerCase();

    // Extract species
    final species = _extractSpecies(lowerText);

    // Extract depth
    final depth = _extractDepth(lowerText);

    // Extract speed
    final speed = _extractSpeed(lowerText);

    // Extract lure information
    final (lure, color) = _extractLureInfo(lowerText);

    // Extract catch count
    final catchCount = _extractCatchCount(lowerText);

    // Extract water conditions
    final waterTemp = _extractWaterTemperature(lowerText);
    final waterClarity = _extractWaterClarity(lowerText);

    // Extract location
    final location = _extractLocation(lowerText);

    // Calculate confidence based on specificity
    final confidence = _calculateConfidence(text);

    return ParsedCaptainReport(
      species: species,
      depth: depth,
      speed: speed,
      lure: lure,
      color: color,
      catchCount: catchCount,
      waterTemp: waterTemp,
      waterClarity: waterClarity,
      location: location,
      confidence: confidence,
    );
  }

  /// Extract target species from text
  String _extractSpecies(String text) {
    if (text.contains('king salmon') || text.contains('king')) {
      return 'King Salmon';
    } else if (text.contains('coho') || text.contains('silver')) {
      return 'Coho Salmon';
    } else if (text.contains('steelhead') || text.contains('rainbow')) {
      return 'Steelhead';
    } else if (text.contains('lake trout') || text.contains('trout')) {
      return 'Lake Trout';
    }
    return 'Unknown';
  }

  /// Extract depth from text
  double _extractDepth(String text) {
    final depthPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:ft|feet|depth)');
    final match = depthPattern.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  /// Extract trolling speed from text
  double _extractSpeed(String text) {
    final speedPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kt|knots|mph|speed)');
    final match = speedPattern.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 1.5; // Default speed
  }

  /// Extract lure and color information
  (String, String) _extractLureInfo(String text) {
    String lure = 'Unknown';
    String color = 'Unknown';

    // Common lure types
    if (text.contains('spoon')) {
      lure = 'Spoon';
    } else if (text.contains('crankbait')) {
      lure = 'Crankbait';
    } else if (text.contains('diver')) {
      lure = 'Diver';
    } else if (text.contains('plug')) {
      lure = 'Plug';
    } else if (text.contains('jig')) {
      lure = 'Jig';
    }

    // Common colors
    if (text.contains('chartreuse')) {
      color = 'Chartreuse';
    } else if (text.contains('gold')) {
      color = 'Gold';
    } else if (text.contains('silver')) {
      color = 'Silver';
    } else if (text.contains('black')) {
      color = 'Black';
    } else if (text.contains('orange')) {
      color = 'Orange';
    } else if (text.contains('white')) {
      color = 'White';
    }

    return (lure, color);
  }

  /// Extract number of fish caught
  int _extractCatchCount(String text) {
    final catchPattern = RegExp(r'(\d+)\s*(?:caught|landed|fish|caught)');
    final match = catchPattern.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  /// Extract water temperature from text
  double _extractWaterTemperature(String text) {
    final tempPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:°F|degrees|temp|water)');
    final match = tempPattern.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  /// Extract water clarity from text
  String _extractWaterClarity(String text) {
    if (text.contains('ultra clear') || text.contains('ultra-clear')) {
      return 'Ultra Clear';
    } else if (text.contains('clear')) {
      return 'Clear';
    } else if (text.contains('mixed') || text.contains('mixed green')) {
      return 'Mixed';
    } else if (text.contains('muddy') || text.contains('stained')) {
      return 'Muddy';
    }
    return 'Unknown';
  }

  /// Extract location from text
  String _extractLocation(String text) {
    // Lake Michigan location references
    if (text.contains('north')) return 'North Lake';
    if (text.contains('south')) return 'South Lake';
    if (text.contains('east')) return 'East Shore';
    if (text.contains('west')) return 'West Shore';
    if (text.contains('chicago')) return 'Chicago Area';
    if (text.contains('milwaukee')) return 'Milwaukee';
    if (text.contains('grand haven')) return 'Grand Haven';
    if (text.contains('muskegon')) return 'Muskegon';

    return 'General Area';
  }

  /// Calculate confidence score based on specificity
  double _calculateConfidence(String text) {
    double confidence = 0.5; // Base confidence

    // Increase confidence based on specificity
    if (text.contains('depth')) confidence += 0.1;
    if (text.contains('temperature')) confidence += 0.1;
    if (text.contains('clarity')) confidence += 0.05;
    if (text.contains('speed') || text.contains('knot')) confidence += 0.05;
    if (text.contains('lure') || text.contains('color')) confidence += 0.1;
    if (text.contains('caught') || text.contains('landed')) confidence += 0.1;

    return (confidence).clamp(0.3, 1.0);
  }

  /// Manually inject a captain report (for testing)
  void injectCaptainReport({
    required String captainName,
    required String species,
    required double depth,
    required double speed,
    required String lure,
    required String color,
    required int catchCount,
    required double waterTemp,
    required String waterClarity,
    required String location,
  }) {
    final reportDate = DateTime.now();

    final report = CaptainReport(
      id: 'report_injected_${reportDate.millisecondsSinceEpoch}',
      captainName: captainName,
      reportDate: reportDate,
      species: species,
      depth: depth,
      speed: speed,
      lure: lure,
      color: color,
      catchCount: catchCount,
      waterTemp: waterTemp,
      waterClarity: waterClarity,
      location: location,
      confidence: 0.9, // High confidence for injected data
    );

    database.storeCaptainReport(report);
    eventBus.emit(
      CaptainReportParsedEvent(
        reportId: report.id,
        species: species,
        depth: depth,
        lure: lure,
        catchCount: catchCount,
        timestamp: reportDate,
      ),
    );

    if (kDebugMode) {
      print(
        '[CaptainReportParserAgent] Injected report from $captainName: '
        '$catchCount $species at $depth ft',
      );
    }
  }

  /// Get recent reports
  List<CaptainReport> getRecentReports({int hours = 24}) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    return database.captainReports.values
        .where((report) => report.reportDate.isAfter(cutoff))
        .toList();
  }

  /// Get reports by species
  List<CaptainReport> getReportsBySpecies(String species) {
    return database.getCaptainReportsBySpecies(species);
  }
}

/// Model for parsed captain report data
class ParsedCaptainReport {
  const ParsedCaptainReport({
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
