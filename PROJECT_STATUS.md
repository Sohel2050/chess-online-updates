# PROJECT STATUS — Chess App: Firebase → Self-Hosted Migration

> **Read this first if you're picking up this project in a new conversation.**
> This document summarizes everything that has been built so far and
> everything that still needs to be done. The codebase in this zip
> (`flutter_app/` + `backend/`) reflects everything marked "done" below.

## What this project is

A Flutter chess app (multiplayer, puzzles, chat, friends, ranking, admin
panel) originally built entirely on Firebase (Firestore, Firebase Auth,
Cloud Functions, Cloud Messaging) plus ZegoCloud for in-game voice chat.
This project is a full migration off Firebase onto a self-hosted
Node.js + MongoDB backend, with LiveKit replacing ZegoCloud for voice.

## ✅ What's done (code-complete, not yet deployed/tested)

### Backend (new — replaces Firebase entirely)
- **Auth**: signup/login/guest via JWT, session restore (`GET /auth/me`)
- **Admin panel API**: user stats, database stats, guest cleanup
  (paginated — safe for tens of millions of users), game-room cleanup,
  generic key/value config store (`/admin/config/:key`,
  `/public/config/:key`) used for ads settings, game-mode settings,
  AdMob/AppLovin/monetization config, app version config, and the
  Play-screen feature toggles (see below)
- **Chat**: message send/history/unread-count, real-time push via Socket.IO
- **Friends**: request/accept/decline/block/search, real-time push
- **Ranking**: leaderboard by rating type (classical/blitz/tempo)
- **Puzzles API**: list/filter by difficulty, per-user progress tracking
- **Game invites**: friend-to-friend private game invites (REST, since
  the invited friend may be offline), real-time push when online
- **Real-time game sync (Socket.IO)**: matchmaking (rating-based),
  private rooms via room code, move sync, resign, draw offer/accept,
  rematch, audio-room state sync, spectator mode, **60-second reconnect
  grace period** before a disconnected player forfeits
- **LiveKit integration**: `POST /livekit/token` issues short-lived
  access tokens for the in-game voice feature (replaces ZegoCloud)
- **User profile**: CRUD, profile image upload (multer + sharp,
  compressed server-side), online/presence status
- **Real email**: password reset and email verification actually send
  via SMTP (nodemailer) if configured; otherwise logged to console (see
  Known Gaps below)
- **Migration scripts** (`backend/scripts/migration/`):
  `migrateFirestoreToMongo.js` (users, friends, chat, games, config) and
  `importPuzzlesFromAsset.js` (puzzles, from the app's bundled JSON —
  Lichess-sourced puzzles use `tags[0]` as the theme fallback)

### Flutter app
- **Firebase fully removed**: no `firebase_auth`, `firebase_core`,
  `firebase_messaging`, `firebase_storage`, `cloud_firestore`, or
  `onesignal_flutter` anywhere in `lib/` or `pubspec.yaml`. Verified via
  `grep -rln "firebase\|onesignal" lib/` returning nothing.
- Every service now talks to the new backend instead of Firebase:
  `auth_service.dart` (new), `api_client.dart` (new — JWT storage, HTTP
  helpers, JWT-decode for current user ID), `game_socket_service.dart`
  (new — Socket.IO wrapper, singleton, connected app-wide from
  `home_screen.dart`), `chat_service.dart`, `friend_service.dart`,
  `admin_service.dart`, `user_service.dart`, `game_invite_service.dart`
  (new), `ranking_service.dart` (new), `poll_service.dart`,
  `saved_game_service.dart`, `monetization_service.dart`,
  `version_service.dart`, `in_app_purchase_service.dart`,
  `livekit_token_service.dart` (new)
- `game_provider.dart` fully rewired onto sockets — zero Firestore calls
  remain in it
- Dead files deleted: `game_service.dart`, `migration_service.dart` (the
  old Firestore one, not the new backend scripts), `zego_provider.dart`,
  `zego_config_model.dart`, `push_notification/notification_service.dart`,
  `firebase_options.dart`
- All `Timestamp` (cloud_firestore) usages converted to plain `DateTime`
  across every model that had them
- **UI/UX**: Play screen redesigned (colored card-style rows for Play
  Online / Computer / Local Multiplayer, each with icon/subtitle/chevron),
  glowing border on the selected game-mode carousel card, dark-green
  home screen header (glowing ring around avatar, star rating, friends
  count pill), dark theme on Home + Play screens, admin-controlled live
  show/hide toggles for each Play option (`PlayOptionTile`,
  `AdminService.watchPlayFeatures()`)
- **New "AI Move" button** in vs-Computer mode: lets Stockfish play the
  best move on the human's behalf on request (separate from the CPU
  opponent's own moves)
- **Puzzles expanded from 48 → 548**: 500 new puzzles pulled from the
  Lichess open puzzle database (CC0 license), each verified move-legal
  with `python-chess` before inclusion, split ~100 per difficulty
  (beginner/easy/medium/hard/expert)
- **Puzzle hint system fixed**: puzzles with no hand-written hints (all
  500 new ones) now get 3 auto-generated hints derived from the theme
  tag and solution move, via `PuzzleModel.effectiveHintCount` — previously
  the hint button silently did nothing for these puzzles
- **Puzzle "stuck after wrong move" bug fixed**: in a multi-move puzzle,
  playing a wrong move on move 2+ used to reset the board all the way to
  move 0 while the provider's internal progress stayed put, desyncing
  the two and effectively locking the puzzle. `_resetBoardState()` now
  replays up to the confirmed progress instead of always resetting to
  the start (except the intentional "Show Solution" full replay, which
  still resets to move 0 on purpose)

## ❌ What's NOT done yet

### Infrastructure (nothing deployed yet — this is the big one)
- [ ] Buy a VPS
- [ ] Install Node.js, MongoDB, Nginx, Docker, SSL on it
- [ ] **Run MongoDB as a replica set** — required for the
      `POST /users/game-result` transaction (rating updates); a plain
      standalone `mongod` will throw "Transaction numbers are only
      allowed on a replica set member"
- [ ] Deploy the backend and confirm it boots against a real MongoDB
- [ ] Set up LiveKit (Cloud account or self-hosted) and put the API
      key/secret/URL in `.env`
- [ ] Configure SMTP in `.env` for real password-reset/verification
      emails (optional — without it, these just log to console instead
      of sending, per `config/email.js`)
- [ ] Domain + HTTPS (mobile apps generally refuse plain HTTP backends)

### Data
- [ ] Run `migrateFirestoreToMongo.js` against the real Firestore project
      to bring over existing users/friends/chat/games/config
- [ ] Run `importPuzzlesFromAsset.js` against the new 548-puzzle
      `puzzles.json` to load them into MongoDB (the app's Flutter side
      now fetches puzzles from the backend, not the bundled asset, once
      wired up — see `puzzle_service.dart`)

### Known gaps / deliberately deferred
- Password reset / email verification are real (SMTP) but need
  `SMTP_HOST/USER/PASS` set in `.env` — unset means "logged, not sent"
- Matchmaking queue and reconnect-grace timers are **in-memory**, single
  Node-process only — fine for one VPS, would need Redis if ever running
  multiple backend instances behind a load balancer
- Profile images are stored on local disk (`backend/uploads/`) — fine
  for one VPS, would need S3-compatible storage to scale to multiple
  instances
- Chat/friend-request/game-invite pushes are real-time via Socket.IO now,
  with polling only as a fallback safety net (not the primary mechanism)
- Server does not validate chess move legality (client-trusted) — same
  trust model the old Firestore version had
- Carousel background image on the Play screen is still the app's
  original bundled asset, not a pixel-perfect match to any reference
  screenshot provided during UI redesign work
- Puzzles/Friends/Settings screens (and any screen besides Home/Play)
  were not included in the dark-theme redesign pass
- The vs-Computer "Undo" button was flagged for review but not
  specifically changed (separate from the new "AI Move" button, which
  was implemented)

### ⚠️ THE BIGGEST GAP
**None of this has ever been compiled.** Every single change across this
entire migration was verified only by counting matched
braces/parens/brackets (`open braces == close braces`, etc.) — there is
no Flutter SDK in the environment this was built in, so `flutter pub
get`, `flutter analyze`, and `flutter run` have never actually been run
against this code. The backend was syntax-checked (`node --check`) and
dry-boot-tested (fails only on missing `MONGO_URI`, as expected) for
every file, which is a stronger guarantee than the Flutter side has.

**The single most valuable next step in a new conversation is:**
1. Run `flutter pub get` and `flutter analyze` (or open in an IDE) and
   paste back whatever errors appear — there will likely be a handful of
   small issues (typos, minor signature mismatches) that are fast to fix
   once an actual compiler points at them.
2. In parallel or after that: buy the VPS and deploy the backend per
   `backend/README.md`.

## Where to find things

- `backend/README.md` — full API endpoint reference, Socket.IO event
  reference, setup steps, migration instructions, all known limitations
  restated with more detail than this file
- `backend/.env.example` — every environment variable the backend needs,
  with comments explaining each
- `flutter_app/lib/services/api_client.dart` — set `baseUrl` here to your
  deployed backend's real URL before building
