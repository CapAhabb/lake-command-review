import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:starter_app/services/seagull_current_service.dart';

void main() {
  test('uses Seagull browser-safe latest API for live station data', () async {
    var requestCount = 0;
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final client = MockClient((request) async {
      requestCount++;
      expect(
        request.url.toString(),
        'https://seagull-api.glos.org/api/v2/obs-latest',
      );
      return http.Response(
        jsonEncode([
          {
            'obs_dataset_id': 153,
            'parameters': [
              {
                'parameter_id': 2471,
                'observations': [
                  {'timestamp': timestamp, 'value': 0.5},
                ],
              },
              {
                'parameter_id': 2478,
                'observations': [
                  {'timestamp': timestamp, 'value': 0.03},
                ],
              },
              {
                'parameter_id': 2498,
                'observations': [
                  {'timestamp': timestamp, 'value': 0.04},
                ],
              },
            ],
          },
        ]),
        200,
      );
    });
    final service = SeagullCurrentService(client: client);

    final results = await Future.wait([
      service.fetchLatestLakeMichigan(),
      service.fetchLatestWaveHeights(),
    ]);
    final currents = results[0] as List<SeagullCurrentObservation>;
    final waves = results[1] as List<SeagullScalarObservation>;

    expect(requestCount, 1);
    expect(currents, hasLength(1));
    expect(currents.single.datasetId, 'obs_153_latest');
    expect(currents.single.speedMetersPerSecond, closeTo(0.05, 0.0001));
    expect(waves.single.value, 0.5);
  });

  test('parses the newest shallow valid Seagull ADCP observation', () {
    const response = '''
    {
      "table": {
        "columnNames": [
          "time", "longitude", "latitude", "depth",
          "eastward_sea_water_velocity", "northward_sea_water_velocity"
        ],
        "rows": [
          ["2026-07-10T02:00:00Z", -87.64, 42.70, 3, 0.10, 0.10],
          ["2026-07-10T03:00:00Z", -87.64, 42.70, 9, -0.03, 0.04],
          ["2026-07-10T03:00:00Z", -87.64, 42.70, 3, 0.03, 0.04],
          ["2026-07-10T04:00:00Z", -87.64, 42.70, 0, null, null]
        ]
      }
    }
    ''';

    final observation = SeagullCurrentService.parseLatestObservation(
      response,
      datasetId: 'obs_153_adcp_latest',
    );

    expect(observation, isNotNull);
    expect(observation!.depthMeters, 3);
    expect(observation.observedAt, DateTime.utc(2026, 7, 10, 3));
    expect(observation.speedMetersPerSecond, closeTo(0.05, 0.0001));
    expect(
      observation.directionRadians,
      closeTo(math.atan2(0.04, 0.03), 0.0001),
    );

    final depthObservation = SeagullCurrentService.parseLatestObservation(
      response,
      datasetId: 'obs_153_adcp_latest',
      targetDepthMeters: 9,
    );
    expect(depthObservation!.depthMeters, 9);
  });

  test('returns null when Seagull has no valid velocity pair', () {
    const response = '''
    {
      "table": {
        "columnNames": [
          "time", "longitude", "latitude", "depth",
          "eastward_sea_water_velocity", "northward_sea_water_velocity"
        ],
        "rows": [
          ["2026-07-10T04:00:00Z", -87.64, 42.70, 0, null, null]
        ]
      }
    }
    ''';

    expect(
      SeagullCurrentService.parseLatestObservation(
        response,
        datasetId: 'obs_153_adcp_latest',
      ),
      isNull,
    );
  });

  test('parses latest Seagull wave or wind scalar observation', () {
    const response = '''
    {
      "table": {
        "columnNames": [
          "time", "longitude", "latitude",
          "sea_surface_wave_significant_height"
        ],
        "rows": [
          ["2026-07-10T02:00:00Z", -86.9, 43.1, 0.8],
          ["2026-07-10T03:00:00Z", -86.9, 43.1, 1.2]
        ]
      }
    }
    ''';

    final observation = SeagullCurrentService.parseScalarObservation(
      response,
      datasetId: 'obs_47_latest',
      variable: 'sea_surface_wave_significant_height',
    );

    expect(observation, isNotNull);
    expect(observation!.value, 1.2);
    expect(observation.observedAt, DateTime.utc(2026, 7, 10, 3));
  });

  test('parses Seagull model forecast summary', () {
    const response = '''
    {
      "timestamps": ["2026-07-10T06:00:00Z"],
      "wind_speed": [{"min": 4.0, "mean": 5.2, "max": 7.0}],
      "wind_from_direction": [{"min": "SW", "mean": "WSW", "max": "W"}],
      "sea_surface_wave_significant_height": [
        {"min": 0.4, "mean": 0.8, "max": 1.3}
      ],
      "sea_water_current": [{"min": 0.02, "mean": 0.11, "max": 0.3}],
      "sea_water_current_direction": [
        {"min": "SW", "mean": "W", "max": "NW"}
      ]
    }
    ''';

    final forecast = SeagullCurrentService.parseForecast(response);

    expect(forecast, isNotNull);
    expect(forecast!.waveHeightMeters, 0.8);
    expect(forecast.windSpeedMetersPerSecond, 5.2);
    expect(forecast.currentSpeedMetersPerSecond, 0.11);
    expect(forecast.windFromDirectionDegrees, 247.5);
    expect(forecast.currentDirectionDegrees, 270);
  });
}
