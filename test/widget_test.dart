import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:starter_app/chart_plotter_screen.dart';
import 'package:starter_app/main.dart';

void main() {
  testWidgets('chart plotter loads with all data layers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChartPlotterScreen()));
    await tester.pumpAndSettle();

    // Verify the gptplotter-style app labels are present
    expect(find.text('LakeGuard Pro'), findsOneWidget);
    expect(find.text('AquaPlotter'), findsOneWidget);

    // Verify GPS status is displayed
    expect(find.text('GPS'), findsOneWidget);

    // Verify interactive layer controls are present
    expect(find.text('ON'), findsWidgets);
    expect(find.text('OFF'), findsWidgets);
    expect(find.text('MENU'), findsOneWidget);
  });

  testWidgets('animated current setting updates its owner', (
    WidgetTester tester,
  ) async {
    var enabled = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuPanel(
            animateCurrents: enabled,
            onAnimateCurrentsChanged: (value) => enabled = value,
          ),
        ),
      ),
    );

    expect(find.text('Animated currents'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('animated-current-switch')))
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('animated-current-switch')));
    await tester.pump();

    expect(enabled, isFalse);
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('animated-current-switch')))
          .value,
      isFalse,
    );
  });

  testWidgets('menu exposes data, membership, and tournament controls', (
    WidgetTester tester,
  ) async {
    var noaaEnabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuPanel(
            animateCurrents: true,
            onAnimateCurrentsChanged: (_) {},
            noaaLayersEnabled: noaaEnabled,
            onNoaaLayersChanged: (value) => noaaEnabled = value,
          ),
        ),
      ),
    );

    expect(find.text('DISPLAY & DATA'), findsOneWidget);
    expect(find.text('LAKEGUARD MEMBERSHIP'), findsOneWidget);
    expect(find.text("Captain's Log"), findsOneWidget);
    expect(find.text('Bragging Board'), findsOneWidget);
    expect(find.text('The Galley'), findsOneWidget);
    expect(find.text('MONTHLY BIG-FISH TOURNAMENTS'), findsOneWidget);
    expect(find.text('Tangled Tackle'), findsOneWidget);
    expect(find.text("Larry's Gas Dock"), findsOneWidget);
    expect(find.text('Ludington Tackle Shop'), findsOneWidget);

    final noaaSwitch = find.byKey(const Key('noaa-data-switch'));
    await tester.ensureVisible(noaaSwitch);
    await tester.tap(noaaSwitch);
    await tester.pump();

    expect(noaaEnabled, isTrue);
  });

  testWidgets('menu fits narrow phone screens without overflowing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuPanel(
            animateCurrents: true,
            onAnimateCurrentsChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MAIN MENU  /  SETTINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
