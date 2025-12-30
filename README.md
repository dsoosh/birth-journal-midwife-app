# Położne — Woman Mobile App (Flutter)

Offline-first app for the pregnant person to log labor/postpartum events and sync to the midwife. In-person pairing only (join code shared face-to-face). No alerts in this app; alerts are for midwife tools.

## Canonical Docs (read, do not copy)
- ../birth-journal-backend/docs/context.md
- ../birth-journal-backend/docs/api.md
- ../birth-journal-backend/docs/glossary.md
- ../birth-journal-backend/docs/architecture.md
- ../birth-journal-backend/docs/privacy-security.md

## Tech
- Flutter (Android/iOS)
- State: Provider or Riverpod
- Storage: Hive or sqflite (offline queue)
- HTTP: http or dio

## Env
Copy `.env.example` to `.env` and set:
- API_BASE_URL=http://localhost:8000/api/v1

## Install & Run
- flutter pub get
- flutter run -d android   # or ios
- flutter run -d chrome    # optional for web debugging

## Pairing (In-Person Only)
- Midwife creates a case and shares a short join code face-to-face.
- Woman enters join code → receives case-scoped token.
- Events queue locally and sync when online (idempotent by event_id).

## Features (PoC)
- Log contractions, labor events (incl. mucus_plug), postpartum check-ins.
- Offline queue + retry sync (`/events/sync`, opaque cursor).
- View own event history; no alerts.

## Contracts (strict)
- Event-based, append-only.
- Server derives `track`; client `track` is ignored.
- Use opaque `cursor` only.
- Include `payload_v: 1` in events.

## Testing
- flutter test

## Notes
- Treat ../birth-journal-backend/docs/api.md as authoritative for requests/payloads.
- Safety-first, deterministic rules, no client-side AI.
