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

Copy `.env.example` to `.env` and fill in the Neon connection details, then:

```bash
cd backend
./mvnw spring-boot:run
```

Runs on `http://localhost:8080` by default. Tests: `./mvnw test` (tests use an in-memory H2 database via the `test` profile and never touch Neon).

Schema is generated from the JPA entities by `spring.jpa.hibernate.ddl-auto=update`. It only ever adds tables and columns — it never drops or retypes one. See [SETUP-4](https://trello.com/c/RK032omp) for why there is no migration tool and when to revisit that.

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

Starts a local Postgres and the backend, wired together via the `docker` Spring profile. Backend is reachable at `http://localhost:8080`, Postgres at `localhost:5432`. This is an offline alternative to Neon — the `docker` profile overrides the datasource so nothing points at the hosted database.

The frontend isn't containerized; keep using `flutter run -d chrome` for local dev.

## CI

Every PR and push to `main` runs the backend (Maven build + test) and frontend (Flutter analyze + test) checks — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Contributing

Branch naming and PR conventions are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md). `main` is protected by required CI checks — merges must have passing builds.
