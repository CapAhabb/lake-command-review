import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class SeagullCurrentService {
  SeagullCurrentService({http.Client? client})
    : _client = client ?? http.Client();

  static const _latestObservationsUrl =
      'https://seagull-api.glos.org/api/v2/obs-latest';

  // Official Seagull dataset/parameter IDs. This endpoint is the same
  // browser-safe source used by seagull.glos.org and permits CORS.
  static const _stations = <_SeagullStation>[
    _SeagullStation(
      datasetId: 2,
      latitude: 43.098,
      longitude: -87.8496,
      waveParameterId: 145,
      temperatureParameterId: 148,
      windParameterId: 159,
      surfaceEastParameterId: 781,
      surfaceNorthParameterId: 801,
      surfaceCurrentDepth: 3,
      depthEastParameterId: 784,
      depthNorthParameterId: 804,
      depthCurrentDepth: 9,
    ),
    _SeagullStation(
      datasetId: 38,
      latitude: 45.82526,
      longitude: -84.77217,
      waveParameterId: 211,
      temperatureParameterId: 207,
      windParameterId: 204,
      surfaceEastParameterId: 2861,
      surfaceNorthParameterId: 2889,
      surfaceCurrentDepth: 2.52,
      depthEastParameterId: 4125,
      depthNorthParameterId: 4144,
      depthCurrentDepth: 9.148,
    ),
    _SeagullStation(
      datasetId: 47,
      latitude: 41.755,
      longitude: -86.968,
      waveParameterId: 321,
      temperatureParameterId: 316,
      windParameterId: 315,
    ),
    _SeagullStation(
      datasetId: 87,
      latitude: 42.367168,
      longitude: -87.795225,
      waveParameterId: 751,
      temperatureParameterId: 742,
      windParameterId: 741,
      surfaceEastParameterId: 4193,
      surfaceNorthParameterId: 4195,
      surfaceCurrentDepth: 2,
      depthEastParameterId: 4193,
      depthNorthParameterId: 4195,
      depthCurrentDepth: 2,
    ),
    _SeagullStation(
      datasetId: 88,
      latitude: 42.490632,
      longitude: -87.778883,
      waveParameterId: 762,
      temperatureParameterId: 753,
      windParameterId: 752,
      surfaceEastParameterId: 4199,
      surfaceNorthParameterId: 4201,
      surfaceCurrentDepth: 2,
      depthEastParameterId: 4199,
      depthNorthParameterId: 4201,
      depthCurrentDepth: 2,
    ),
    _SeagullStation(
      datasetId: 153,
      latitude: 42.7017,
      longitude: -87.6466,
      waveParameterId: 2471,
      temperatureParameterId: 2457,
      windParameterId: 2474,
      surfaceEastParameterId: 2478,
      surfaceNorthParameterId: 2498,
      surfaceCurrentDepth: 3,
      depthEastParameterId: 2481,
      depthNorthParameterId: 2501,
      depthCurrentDepth: 9,
    ),
  ];

  final http.Client _client;
  Future<List<dynamic>>? _latestSnapshotFuture;
  DateTime? _latestSnapshotStartedAt;

  void close() => _client.close();

  Future<List<SeagullCurrentObservation>> fetchLatestLakeMichigan({
    double targetDepthMeters = 3,
  }) async {
    final datasets = await _fetchLatestSnapshot();
    final results = <SeagullCurrentObservation>[];
    for (final station in _stations) {
      final dataset = _datasetById(datasets, station.datasetId);
      if (dataset == null) continue;
      final atDepth = targetDepthMeters >= 6;
      final eastId = atDepth
          ? station.depthEastParameterId
          : station.surfaceEastParameterId;
      final northId = atDepth
          ? station.depthNorthParameterId
          : station.surfaceNorthParameterId;
      final depth = atDepth
          ? station.depthCurrentDepth
          : station.surfaceCurrentDepth;
      if (eastId == null || northId == null) continue;
      final east = _observationForParameter(dataset, eastId);
      final north = _observationForParameter(dataset, northId);
      if (east == null || north == null) continue;
      final eastValue = (east['value'] as num?)?.toDouble();
      final northValue = (north['value'] as num?)?.toDouble();
      final eastTimestamp = (east['timestamp'] as num?)?.toInt();
      final northTimestamp = (north['timestamp'] as num?)?.toInt();
      if (eastValue == null ||
          northValue == null ||
          eastTimestamp == null ||
          northTimestamp == null ||
          !_isFresh(eastTimestamp) ||
          !_isFresh(northTimestamp)) {
        continue;
      }
      results.add(
        SeagullCurrentObservation(
          datasetId: 'obs_${station.datasetId}_latest',
          observedAt: DateTime.fromMillisecondsSinceEpoch(
            math.min(eastTimestamp, northTimestamp) * 1000,
            isUtc: true,
          ),
          latitude: station.latitude,
          longitude: station.longitude,
          depthMeters: depth,
          directionRadians: math.atan2(northValue, eastValue),
          speedMetersPerSecond: math.sqrt(
            eastValue * eastValue + northValue * northValue,
          ),
        ),
      );
    }
    return results;
  }

  Future<List<SeagullScalarObservation>> fetchLatestWaveHeights() =>
      _fetchScalarObservations(
        parameterId: (station) => station.waveParameterId,
      );

  Future<List<SeagullScalarObservation>> fetchLatestWindSpeeds() =>
      _fetchScalarObservations(
        parameterId: (station) => station.windParameterId,
      );

  Future<List<SeagullScalarObservation>> fetchLatestSurfaceTemperatures() =>
      _fetchScalarObservations(
        parameterId: (station) => station.temperatureParameterId,
      );

  Future<SeagullForecast?> fetchForecast({
    required double latitude,
    required double longitude,
  }) async {
    final geo = jsonEncode({
      'type': 'Point',
      'coordinates': [longitude, latitude],
    });
    final uri = Uri.https(
      'seagull-api.glos.org',
      '/api/v1/model-data-latest-summaries',
      {'geo': geo},
    );
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parseForecast(response.body);
    } on Exception {
      return null;
    }
  }

  Future<List<dynamic>> _fetchLatestSnapshot() {
    final now = DateTime.now();
    if (_latestSnapshotFuture != null &&
        _latestSnapshotStartedAt != null &&
        now.difference(_latestSnapshotStartedAt!) <
            const Duration(seconds: 30)) {
      return _latestSnapshotFuture!;
    }
    _latestSnapshotStartedAt = now;
    return _latestSnapshotFuture = _requestLatestSnapshot();
  }

  Future<List<dynamic>> _requestLatestSnapshot() async {
    try {
      final response = await _client
          .get(Uri.parse(_latestObservationsUrl))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];
      return jsonDecode(response.body) as List<dynamic>;
    } on Exception {
      return const [];
    }
  }

  static Map<String, dynamic>? _datasetById(
    List<dynamic> datasets,
    int datasetId,
  ) {
    for (final value in datasets) {
      final dataset = value as Map<String, dynamic>;
      if (dataset['obs_dataset_id'] == datasetId) return dataset;
    }
    return null;
  }

  static Map<String, dynamic>? _observationForParameter(
    Map<String, dynamic> dataset,
    int parameterId,
  ) {
    final parameters = dataset['parameters'] as List<dynamic>?;
    if (parameters == null) return null;
    for (final value in parameters) {
      final parameter = value as Map<String, dynamic>;
      if (parameter['parameter_id'] != parameterId) continue;
      final observations = parameter['observations'] as List<dynamic>?;
      if (observations == null || observations.isEmpty) return null;
      return observations.first as Map<String, dynamic>;
    }
    return null;
  }

  static bool _isFresh(int timestamp) {
    final observedAt = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    );
    return DateTime.now().toUtc().difference(observedAt).inHours <= 72;
  }

  static SeagullCurrentObservation? parseLatestObservation(
    String responseBody, {
    required String datasetId,
    double targetDepthMeters = 3,
  }) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final table = decoded['table'] as Map<String, dynamic>?;
    final columns = (table?['columnNames'] as List<dynamic>?)?.cast<String>();
    final rows = table?['rows'] as List<dynamic>?;
    if (columns == null || rows == null || rows.isEmpty) return null;

    final timeIndex = columns.indexOf('time');
    final longitudeIndex = columns.indexOf('longitude');
    final latitudeIndex = columns.indexOf('latitude');
    final depthIndex = columns.indexOf('depth');
    final eastIndex = columns.indexOf('eastward_sea_water_velocity');
    final northIndex = columns.indexOf('northward_sea_water_velocity');
    if ([
      timeIndex,
      longitudeIndex,
      latitudeIndex,
      eastIndex,
      northIndex,
    ].any((index) => index < 0)) {
      return null;
    }

    final validRows = rows
        .cast<List<dynamic>>()
        .where((row) => row[eastIndex] is num && row[northIndex] is num)
        .toList();
    if (validRows.isEmpty) return null;

    validRows.sort((a, b) {
      final timeOrder = DateTime.parse(
        b[timeIndex] as String,
      ).compareTo(DateTime.parse(a[timeIndex] as String));
      if (timeOrder != 0 || depthIndex < 0) return timeOrder;
      final aDepth = (a[depthIndex] as num?)?.toDouble() ?? double.infinity;
      final bDepth = (b[depthIndex] as num?)?.toDouble() ?? double.infinity;
      return (aDepth - targetDepthMeters).abs().compareTo(
        (bDepth - targetDepthMeters).abs(),
      );
    });

    final row = validRows.first;
    final east = (row[eastIndex] as num).toDouble();
    final north = (row[northIndex] as num).toDouble();
    return SeagullCurrentObservation(
      datasetId: datasetId,
      observedAt: DateTime.parse(row[timeIndex] as String),
      latitude: (row[latitudeIndex] as num).toDouble(),
      longitude: (row[longitudeIndex] as num).toDouble(),
      depthMeters: depthIndex >= 0
          ? (row[depthIndex] as num?)?.toDouble()
          : null,
      directionRadians: math.atan2(north, east),
      speedMetersPerSecond: math.sqrt(east * east + north * north),
    );
  }

  Future<List<SeagullScalarObservation>> _fetchScalarObservations({
    required int? Function(_SeagullStation station) parameterId,
  }) async {
    final datasets = await _fetchLatestSnapshot();
    final results = <SeagullScalarObservation>[];
    for (final station in _stations) {
      final id = parameterId(station);
      final dataset = _datasetById(datasets, station.datasetId);
      if (id == null || dataset == null) continue;
      final observation = _observationForParameter(dataset, id);
      final value = (observation?['value'] as num?)?.toDouble();
      final timestamp = (observation?['timestamp'] as num?)?.toInt();
      if (value == null || timestamp == null || !_isFresh(timestamp)) continue;
      results.add(
        SeagullScalarObservation(
          datasetId: 'obs_${station.datasetId}_latest',
          observedAt: DateTime.fromMillisecondsSinceEpoch(
            timestamp * 1000,
            isUtc: true,
          ),
          latitude: station.latitude,
          longitude: station.longitude,
          value: value,
        ),
      );
    }
    return results;
  }

  static SeagullScalarObservation? parseScalarObservation(
    String responseBody, {
    required String datasetId,
    required String variable,
  }) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final table = decoded['table'] as Map<String, dynamic>?;
    final columns = (table?['columnNames'] as List<dynamic>?)?.cast<String>();
    final rows = table?['rows'] as List<dynamic>?;
    if (columns == null || rows == null) return null;
    final timeIndex = columns.indexOf('time');
    final longitudeIndex = columns.indexOf('longitude');
    final latitudeIndex = columns.indexOf('latitude');
    final valueIndex = columns.indexOf(variable);
    if ([
      timeIndex,
      longitudeIndex,
      latitudeIndex,
      valueIndex,
    ].any((index) => index < 0)) {
      return null;
    }
    final validRows =
        rows
            .cast<List<dynamic>>()
            .where((row) => row[valueIndex] is num)
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b[timeIndex] as String,
            ).compareTo(DateTime.parse(a[timeIndex] as String)),
          );
    if (validRows.isEmpty) return null;
    final row = validRows.first;
    return SeagullScalarObservation(
      datasetId: datasetId,
      observedAt: DateTime.parse(row[timeIndex] as String),
      latitude: (row[latitudeIndex] as num).toDouble(),
      longitude: (row[longitudeIndex] as num).toDouble(),
      value: (row[valueIndex] as num).toDouble(),
    );
  }

  static SeagullForecast? parseForecast(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final timestamps = decoded['timestamps'] as List<dynamic>?;
    if (timestamps == null || timestamps.isEmpty) return null;
    double? meanAt(String field) {
      final values = decoded[field] as List<dynamic>?;
      if (values == null || values.isEmpty) return null;
      final first = values.first as Map<String, dynamic>?;
      return (first?['mean'] as num?)?.toDouble();
    }

    String? directionAt(String field) {
      final values = decoded[field] as List<dynamic>?;
      if (values == null || values.isEmpty) return null;
      final first = values.first;
      if (first is String) return first;
      return (first as Map<String, dynamic>?)?['mean'] as String?;
    }

    return SeagullForecast(
      validAt: DateTime.parse(timestamps.first as String),
      waveHeightMeters: meanAt('sea_surface_wave_significant_height'),
      windSpeedMetersPerSecond: meanAt('wind_speed'),
      windFromDirectionDegrees: _directionDegrees(
        directionAt('wind_from_direction'),
      ),
      currentSpeedMetersPerSecond: meanAt('sea_water_current'),
      currentDirectionDegrees: _directionDegrees(
        directionAt('sea_water_current_direction'),
      ),
    );
  }

  static double? _directionDegrees(String? value) {
    if (value == null) return null;
    final numeric = double.tryParse(value);
    if (numeric != null) return numeric;
    const compass = <String>[
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final index = compass.indexOf(value.toUpperCase());
    return index < 0 ? null : index * 22.5;
  }
}

class _SeagullStation {
  const _SeagullStation({
    required this.datasetId,
    required this.latitude,
    required this.longitude,
    required this.waveParameterId,
    required this.temperatureParameterId,
    required this.windParameterId,
    this.surfaceEastParameterId,
    this.surfaceNorthParameterId,
    this.surfaceCurrentDepth,
    this.depthEastParameterId,
    this.depthNorthParameterId,
    this.depthCurrentDepth,
  });

  final int datasetId;
  final double latitude;
  final double longitude;
  final int? waveParameterId;
  final int? temperatureParameterId;
  final int? windParameterId;
  final int? surfaceEastParameterId;
  final int? surfaceNorthParameterId;
  final double? surfaceCurrentDepth;
  final int? depthEastParameterId;
  final int? depthNorthParameterId;
  final double? depthCurrentDepth;
}

class SeagullCurrentObservation {
  const SeagullCurrentObservation({
    required this.datasetId,
    required this.observedAt,
    required this.latitude,
    required this.longitude,
    required this.depthMeters,
    required this.directionRadians,
    required this.speedMetersPerSecond,
  });

  final String datasetId;
  final DateTime observedAt;
  final double latitude;
  final double longitude;
  final double? depthMeters;
  final double directionRadians;
  final double speedMetersPerSecond;
}

class SeagullScalarObservation {
  const SeagullScalarObservation({
    required this.datasetId,
    required this.observedAt,
    required this.latitude,
    required this.longitude,
    required this.value,
  });

  final String datasetId;
  final DateTime observedAt;
  final double latitude;
  final double longitude;
  final double value;
}

class SeagullForecast {
  const SeagullForecast({
    required this.validAt,
    required this.waveHeightMeters,
    required this.windSpeedMetersPerSecond,
    required this.windFromDirectionDegrees,
    required this.currentSpeedMetersPerSecond,
    required this.currentDirectionDegrees,
  });

  final DateTime validAt;
  final double? waveHeightMeters;
  final double? windSpeedMetersPerSecond;
  final double? windFromDirectionDegrees;
  final double? currentSpeedMetersPerSecond;
  final double? currentDirectionDegrees;
}
