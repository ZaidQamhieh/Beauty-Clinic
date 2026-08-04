package com.example.backend;

import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.postgresql.PostgreSQLContainer;

// Shared Postgres container for any test that needs a real database.
// The schema comes from Flyway migrations, not ddl-auto - this is what
// lets tests exercise the actual exclusion constraint, triggers and
// extensions that H2 could never run.
//
// Started manually (no @Testcontainers/@Container) instead of letting
// JUnit manage the lifecycle: this field lives on the shared superclass,
// so the @Testcontainers extension would stop it after the first test
// class finishes, breaking every class that runs after. Ryuk reaps it
// at JVM exit instead.
public abstract class AbstractIntegrationTest {

    @ServiceConnection
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:16-alpine");

    static {
        POSTGRES.start();
    }
}
