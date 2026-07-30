# Beauty Clinic

A cosmetic/aesthetic clinic booking and management platform (not a general medical clinic).

## Stack

- **Backend:** Spring Boot (Java 21, Maven)
- **Frontend:** Flutter — **web only**
- **Database:** PostgreSQL (separate `clinical` and `billing` schemas)
- **Cache:** Redis
- **Reverse proxy:** Nginx (planned)
- **Orchestration:** Docker Compose (planned)

## Repo structure

```
backend/    Spring Boot API
frontend/   Flutter web app
```

## Getting started

### Backend

```bash
cd backend
./mvnw spring-boot:run
```

Runs on `http://localhost:8080` by default. Tests: `./mvnw test`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Running with Docker

```bash
cp .env.example .env
docker compose up --build
```

Starts Postgres (with `clinical` and `billing` schemas created on first boot) and the backend, wired together via the `docker` Spring profile. Backend is reachable at `http://localhost:8080`, Postgres at `localhost:5432`.

Redis and an Nginx reverse proxy aren't wired into Compose yet — this only covers backend + Postgres for now. Frontend isn't containerized either; keep using `flutter run -d chrome` for local dev.

## CI

Every PR and push to `main` runs the backend (Maven build + test) and frontend (Flutter analyze + test) checks — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Contributing

Branch naming and PR conventions are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md). `main` is protected by required CI checks — merges must have passing builds.
