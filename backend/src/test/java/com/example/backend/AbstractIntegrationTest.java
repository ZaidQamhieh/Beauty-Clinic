package com.example.backend;

import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.postgresql.PostgreSQLContainer;

// Real Postgres on Flyway, so tests exercise constraints and triggers H2 cannot run.
public abstract class AbstractIntegrationTest {

    @ServiceConnection
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:16-alpine");

    // Started manually: @Testcontainers would stop it after the first test class.
    static {
        POSTGRES.start();
    }
}
