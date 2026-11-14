# Stub: builder brief

Stub is a calm expense tracker: a monthly budget, quick spend entry with a printed
receipt, bill splitting with friends, weekly stubs and statistics.

## Stack
- Flutter stable 3.50 or newer (iOS and Android), Dart 3. Material widgets come from the
  `material_ui` package: import `package:material_ui/material_ui.dart`, not `flutter/material.dart`.
- State: one `AppModel` (a `ChangeNotifier` around the store) shared through `StubScope`.
  Read with `StubScope.of(context)`; change data with `model.write((store) => ...)`.
  Navigation is the plain `Navigator`. No Riverpod or go_router.
- Storage: SQLite through the `sqlite3` package with hand-written SQL (no code generation),
  local-only for Release 1. Schema in `lib/data/db.dart`; all reads and writes go through
  `StubStore` (`lib/data/store.dart` and its `store_*.dart` parts). No accounts yet.
- Money is always whole paise (`int`). Use `lib/core/money.dart`; never doubles.

## Folders
```
lib/
  core/        tokens, theme, money, split maths
  data/        db schema, models, StubStore (spends, friends, bills)
  ui/kit/      shared widgets: card, sheet, pill button…   (D1)
  features/    home, add (a glass sheet), receipts, stats, friends, bills
test/          unit tests for pure logic, one widget test per screen
```

## Rules
- One phase per session; finish, run analyze and tests, commit as "<ID> <name>".
- Edit only the files a phase names. Keep files under about 300 lines.
- Pure logic (totals, formatting, splits) gets unit tests. No end-to-end suite yet.
- Colours, radii and spacing come from `lib/core/tokens.dart` (orange accent for actions).
  Each category and friend has its own colour in `lib/core/categories.dart`.
- Pop-ups are frosted glass (`lib/ui/kit/glass.dart`: `showGlassSheet`, `GlassDialog`).
  Add a spend opens as a tall glass sheet over Home, not a new page.
- In the UI, say "receipt", never "stub" (the app name is still to be decided).
- Keep forms short: anything with more than a couple of options opens a bottom sheet
  (see `category_sheet.dart`, `split_sheet.dart`).
- CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on every push.
  It also renders preview PNGs (`test/golden/`, tag `golden`) and pushes them to the
  `previews` branch under a folder named after the branch, so screens can be checked by eye.

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
- [x] D2 Data layer: schema, spends, splits and friends, groups, bills and autopay, with tests
- [x] D3 Shell: tab bar and + button (Stubs and Statistics are placeholders)
- [x] D4 Welcome and budget
- [x] D5 Home: balance card, today, this month's spends, long-press delete with undo
- [x] D6 Add a spend with splits (who paid; equal, amounts, percent, shares) and a plain receipt
- [x] Friends, part 1: balances, add a friend, settle up in full or part
- [ ] Friends, part 2: groups, activity feed, invites, reminders
- [x] Stubs (weekly receipts) and Statistics (Week / Month / Year trend line, top spending)
- [x] Paper receipt (`lib/ui/kit/paper.dart`), bundled fonts (Nunito, IBM Plex Mono), category icons
- [ ] Bills and autopay screen (the store already supports it)
- [ ] Visual polish against the prototype, checked on a simulator
- [ ] Settings: edit budget, edit a spend
