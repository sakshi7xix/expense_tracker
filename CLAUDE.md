# Bilby: builder brief

Bilby is a calm expense tracker: a monthly budget, quick spend entry with a printed
receipt, bill splitting with friends, and statistics.

## Stack
- Flutter stable 3.50 or newer (iOS and Android), Dart 3. Material widgets come from the
  `material_ui` package: import `package:material_ui/material_ui.dart`, not `flutter/material.dart`.
- State: one `AppModel` (a `ChangeNotifier` around the store) shared through `StubScope`.
  Read with `StubScope.of(context)`; change data with `model.write((store) => ...)`.
  Navigation is the plain `Navigator`. No Riverpod or go_router.
- Storage: SQLite through the `sqlite3` package with hand-written SQL (no code generation).
  The phone is the home of personal data; only what is shared with friends goes online. Schema in `lib/data/db.dart`; all reads and writes go through
  `StubStore` (`lib/data/store.dart` and its `store_*.dart` parts).
- Online: Supabase (Mumbai). Optional email-code sign-in (`lib/data/auth.dart`, `supabase_auth.dart`;
  tests use `test/fake_auth.dart`). Only the publishable key is in the app; the secret key never is.
  Schema and row level security live in `supabase/migrations/`; every table gets RLS and pgTAP tests
  in `supabase/tests/database/` (CI job `database`). Sessions are kept in secure storage.
- Money is always whole paise (`int`). Use `lib/core/money.dart`; never doubles.

## Folders
```
lib/
  core/        tokens, theme, money, split maths
  data/        db schema, models, StubStore (spends, friends, bills)
  ui/kit/      shared widgets: card, sheet, pill button…   (D1)
  features/    home, add (a glass sheet), receipts (one spend, opened), stats, friends
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
- The app is called **Bilby**. In the UI, say "receipt", never "stub" (the Dart package is still
  named `stub` internally; that is never shown). Logo: `lib/ui/kit/bilby_mark.dart` (one charcoal
  line on cream, orange nose); app icon PNGs in `assets/icon/`, generated with flutter_launcher_icons.
- Tabs: Home, Statistics, Friends. There is no receipts tab: a receipt shows when a spend is
  added and when one is tapped (Edit, Copy, Delete).
- Keep forms short: anything with more than a couple of options opens a bottom sheet
  (see `category_sheet.dart`, `split_sheet.dart`).
- CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on every push.
  It also renders preview PNGs (`test/golden/`, tag `golden`) and pushes them to the
  `previews` branch under a folder named after the branch, so screens can be checked by eye.

## Design source
The "Stub, quiet" prototype: card-style Home, Add a spend with splits and a 3D
receipt, Statistics, Friends (balances, groups, activity, settle up). The Receipts
tab was dropped, and a Bills tab was tried and dropped; the store still supports bills.

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
- [x] D15 Friends, part 2: Friends / Groups / Activity tabs, groups with their own balances and
  spends, split with a whole group, copy a reminder (invites still to do)
- [x] Stubs (weekly receipts) and Statistics (Week / Month / Year trend line, top spending)
- [x] Paper receipt (`lib/ui/kit/paper.dart`), bundled fonts (Nunito, IBM Plex Mono), category icons
- [x] D14 Receipts tab removed; a spend opens as its receipt (edit title and category, copy, delete)
- [ ] Visual polish against the prototype, checked on a simulator
- [x] S1 Sign-in (email code, name, 18+), Settings (budget, privacy, terms, licences, help, sign out,
  delete account), profiles table with RLS and tests
- [x] S2 Friends online: invite by email or code (share sheet), friend requests and updates in a bell
  on Home and Friends, shared splits and payments synced both ways (`lib/data/sync.dart`, tested with
  `test/fake_remote.dart`), friends' spends read-only, times in Activity. Groups are not synced yet.
- [x] S3 Name and logo: Bilby, minimal-line receipt bilby as the app icon and in the app
- [x] S6 Friend codes: everyone has a personal 8-character code (Settings, Add a friend); friends
  are added only by typing it, they accept from the bell, then splits sync. No email or WhatsApp invites.
- [ ] Edit a spend's amount and split
