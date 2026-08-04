# Beauty Clinic

A cosmetic/aesthetic clinic booking and management platform (not a general medical clinic).

## Stack

- **Backend:** Spring Boot 4 (Java 21, Maven)
- **Frontend:** Flutter — **web only**
- **Database:** PostgreSQL, hosted on Neon
- **Orchestration:** Docker Compose

## Repo structure

```
backend/    Spring Boot API
frontend/   Flutter web app
```

## Getting started

### Backend

Create a `.env` in the repo root with the Neon connection details:

```properties
DB_URL=jdbc:postgresql://<your-neon-host>.neon.tech:5432/neondb?sslmode=require
DB_USER=
DB_PASSWORD=
AUTH_JWT_SECRET=          # required, Base64, at least 32 bytes
AUTH_TOKEN_ISSUER=https://beauty-clinic.example
AUTH_ACCESS_TTL=15m
AUTH_REFRESH_TTL=7d
```

Then:

```bash
cd backend
./mvnw spring-boot:run
```

Runs on `http://localhost:8080` by default. Tests: `./mvnw test` — they start a throwaway PostgreSQL container via Testcontainers, so Docker must be running and Neon is never touched.

Schema comes from Flyway migrations in `backend/src/main/resources/db/migration`. Hibernate is set to `ddl-auto=validate`, so it checks the entities against that schema and never changes it.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Running with Docker

```bash
docker compose up --build
```

Every variable has a default except `AUTH_JWT_SECRET`, which must be set in `.env` or the stack refuses to start.

Starts a local Postgres and the backend, wired together via the `docker` Spring profile. Backend is reachable at `http://localhost:8080`, Postgres at `localhost:5432`. This is an offline alternative to Neon — the `docker` profile overrides the datasource so nothing points at the hosted database.

The frontend isn't containerized; keep using `flutter run -d chrome` for local dev.

## CI

Every PR and push to `main` runs the backend (Maven build + test) and frontend (Flutter analyze + test) checks — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Contributing

Branch naming and PR conventions are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md). `main` is protected by required CI checks — merges must have passing builds.
