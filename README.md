# Lake Command App

This Flutter app powers the current Lake Command In Depth experience.

It opens with a guided splash screen, then moves into a structured set of
menus for trip planning, lake overview, species guidance, departures, and
supporting on-the-water decision flows.

## Main Areas

- Splash entry into the menu system
- Lake overview and general fish location guidance
- Species-specific menu branches
- Trip controls and recommended route flow
- Supporting trip intel and operational screens

## Run Locally

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter test
```

## Notes

- Main app entry: `lib/main.dart`
- Widget coverage: `test/widget_test.dart`
- Project checklist: `DATA_PROVIDER_CHECKLIST.md`
