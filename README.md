# Lake Command App

This Flutter app powers the current Lake Command In Depth experience.

It currently presents the Core Command hardware-console shell for the Lake
Command product family. The product model selector and bottom module controls
are reviewable UI states inside the same program shell.

Cross-application switching is not functional yet. Selecting another product
model or toggling an armed module does not launch a separate application; those
states are placeholders for the future shared command layer.

## Main Areas

- Splash entry into the menu system
- Lake overview and general fish location guidance
- Core Command product model selector
- Active and armed module control states
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
