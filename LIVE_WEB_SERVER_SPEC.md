# Live watch link: what the SERVER must provide

The app now has a **Share link** button (Live sheet, Public ON). It shares
`https://chess-api.albonik.com/live/<code>` where `<code>` = the game's room code.
The app side is done. The server needs the 3 small parts below.

## 1. JSON endpoint (no login needed)
`GET /games/live/:code`

* `:code` = the room code (same value the app puts in the link) or the game id.
* Only answer when the game has **public Live ON**; otherwise `404`.
* Response:
```json
{
  "gameId": "…",
  "status": "active",          // or "completed" / "aborted"
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "endReason": null,           // e.g. "timeout", "checkmate"
  "white": { "name": "Ali",  "rating": 1250, "photoUrl": "https://…" },
  "black": { "name": "Sam",  "rating": 1190, "photoUrl": "https://…" },
  "whiteTimeMs": 180000,
  "blackTimeMs": 175000
}
```
* Never include user ids, emails or tokens. `photoUrl` only if it is a normal https URL
  (built-in avatars such as `assets/images/avatar_8.png` are app files: send null for them).
* The app also uses this endpoint to turn the code into a `gameId` (it only reads `gameId`).

## 2. The web page
`GET /live/:code` -> serve `server_web/live.html` (it is a plain static file; the same file for every code).
Add to the HTML `<head>` per game (optional, for nicer WhatsApp/Facebook previews):
`og:title` "A vs B – live chess", `og:image`.

## 3. Open-in-app (Android App Links)
`/.well-known/assetlinks.json` on the API host must already exist for `/g/` links.
The manifest now also has `/live/` on the same host, so the same file works.
Without it the link opens the browser page (which has an "Open in app" button).

## Notes
* The web page polls the JSON every 2 s (simple, no socket needed). Add a rate limit (e.g. 60 req/min/IP).
* Emoji reactions stay app-only for now.
