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

## CI

Every PR and push to `main` runs the backend (Maven build + test) and frontend (Flutter analyze + test) checks — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Contributing

Branch naming, PR review rules, and merge requirements are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md). `main` is protected — all changes land via reviewed, CI-passing pull requests.
