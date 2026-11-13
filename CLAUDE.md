# Stub: builder brief

Stub is a calm expense tracker: a monthly budget, quick spend entry with a printed
receipt, bill splitting with friends, weekly stubs and statistics.

## Stack
- Flutter (iOS and Android), Dart 3.
- State: Riverpod (added in D3). Navigation: go_router (D3).
- Storage: Drift on SQLite, local-only for Release 1 (D2). No accounts yet.
- Money is always whole paise (`int`). Use `lib/core/money.dart`; never doubles.

## Folders
```
lib/
  core/        tokens, theme, money, split maths
  data/        drift tables, repositories, seed            (D2)
  ui/kit/      shared widgets: card, sheet, pill button…   (D1)
  features/    home, add, stubs, stats, friends, bills
test/          unit tests for pure logic, one widget test per screen
```

## Rules
- One phase per session; finish, run analyze and tests, commit as "<ID> <name>".
- Edit only the files a phase names. Keep files under about 300 lines.
- Pure logic (totals, formatting, splits) gets unit tests. No end-to-end suite yet.
- Colours, radii and spacing come from `lib/core/tokens.dart`. One accent: green.
- CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on every push.

## Design source
The "Stub, quiet" prototype: card-style Home, Add a spend with splits and a 3D
receipt, weekly Stubs, Statistics, Friends (balances, groups, activity, settle up).

## First run on a new machine
The `android/` and `ios/` folders are not in the repo yet. Generate them once:
```
flutter create --platforms=ios,android --project-name stub .
flutter pub get
flutter run
```

## Phase status
- [x] D0 Setup: project, tokens, theme, money and split logic with tests, CI
- [ ] D1 Design kit
- [ ] D2 Data layer
- [ ] D3 Shell and navigation
- [ ] D4 Welcome and budget
- [ ] D5 Home
- [ ] D6 Add a spend (with splits)
