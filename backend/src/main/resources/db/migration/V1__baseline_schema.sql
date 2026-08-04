CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION activity_log_reject_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'activity_log is append-only; % is not permitted', TG_OP;
END;
$$;

CREATE FUNCTION block_update_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% is insert-only; % is not permitted', TG_TABLE_NAME, TG_OP;
END;
$$;

CREATE TABLE user_account (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email              varchar(255) NOT NULL UNIQUE,
    phone              varchar(30) UNIQUE,
    password_hash      varchar(255) NOT NULL,
    full_name          varchar(150) NOT NULL,
    role               varchar(30) NOT NULL
                       CHECK (role IN ('PATIENT','RECEPTIONIST','DOCTOR','ADMIN')),
    status             varchar(20) NOT NULL DEFAULT 'ACTIVE'
                       CHECK (status IN ('ACTIVE','DEACTIVATED')),
    language_pref      varchar(5) NOT NULL DEFAULT 'en'
                       CHECK (language_pref IN ('en','ar')),
    failed_login_count integer NOT NULL DEFAULT 0,
    lockout_strikes    integer NOT NULL DEFAULT 0,
    locked_until       timestamptz,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refresh_token (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    token_hash varchar(255) NOT NULL UNIQUE,
    issued_at  timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL
);
CREATE INDEX idx_refresh_token_user ON refresh_token(user_id);

CREATE TABLE doctor (
    user_id        uuid PRIMARY KEY REFERENCES user_account(id) ON DELETE RESTRICT,
    specialty      varchar(120),
    license_number varchar(60) UNIQUE,
    bio            text,
    availability   jsonb NOT NULL DEFAULT '[]'::jsonb
                   CHECK (jsonb_typeof(availability) = 'array')
);

CREATE TABLE service (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name             varchar(150) NOT NULL,
    name_ar          varchar(150),
    duration_minutes integer NOT NULL CHECK (duration_minutes > 0),
    price            numeric(10,2) NOT NULL CHECK (price >= 0),
    is_active        boolean NOT NULL DEFAULT true
);

CREATE TABLE doctor_service (
    doctor_id  uuid NOT NULL REFERENCES doctor(user_id) ON DELETE CASCADE,
    service_id uuid NOT NULL REFERENCES service(id) ON DELETE CASCADE,
    PRIMARY KEY (doctor_id, service_id)
);
CREATE INDEX idx_doctor_service_service ON doctor_service(service_id);

CREATE TABLE patient (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid UNIQUE REFERENCES user_account(id) ON DELETE SET NULL,
    first_name    varchar(100) NOT NULL,
    last_name     varchar(100) NOT NULL,
    date_of_birth date,
    phone         varchar(30),
    email         varchar(255),
    address       text,
    allergies     text,
    language_pref varchar(5) NOT NULL DEFAULT 'en'
                  CHECK (language_pref IN ('en','ar')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_patient_name_trgm ON patient
    USING gin ((first_name || ' ' || last_name) gin_trgm_ops);
CREATE INDEX idx_patient_phone ON patient(phone);
CREATE INDEX idx_patient_email ON patient(lower(email));

CREATE TABLE appointment (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id         uuid NOT NULL REFERENCES patient(id) ON DELETE RESTRICT,
    doctor_id          uuid NOT NULL REFERENCES doctor(user_id) ON DELETE RESTRICT,
    service_id         uuid NOT NULL REFERENCES service(id) ON DELETE RESTRICT,
    start_time         timestamptz NOT NULL,
    end_time           timestamptz NOT NULL,
    status             varchar(20) NOT NULL DEFAULT 'BOOKED'
                       CHECK (status IN ('BOOKED','COMPLETED','CANCELLED','NO_SHOW')),
    reason             text,
    created_by_user_id uuid REFERENCES user_account(id) ON DELETE SET NULL,
    cancelled_at       timestamptz,
    replaces_appointment_id uuid REFERENCES appointment(id) ON DELETE SET NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CHECK (end_time > start_time),
    CONSTRAINT appointment_no_double_booking EXCLUDE USING gist (
        doctor_id WITH =,
        tstzrange(start_time, end_time) WITH &&
    ) WHERE (status <> 'CANCELLED')
);
CREATE INDEX idx_appointment_patient ON appointment(patient_id);
CREATE INDEX idx_appointment_doctor_start ON appointment(doctor_id, start_time);
CREATE INDEX idx_appointment_status_start ON appointment(status, start_time);

CREATE TABLE treatment_record (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id       uuid NOT NULL REFERENCES appointment(id) ON DELETE RESTRICT,
    recorded_by_user_id  uuid NOT NULL REFERENCES user_account(id) ON DELETE RESTRICT,
    diagnosis            text,
    treatment            text,
    notes                text,
    amends_record_id     uuid UNIQUE REFERENCES treatment_record(id) ON DELETE RESTRICT,
    created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_treatment_record_appointment ON treatment_record(appointment_id);

CREATE TABLE notification (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid REFERENCES user_account(id) ON DELETE CASCADE,
    appointment_id uuid REFERENCES appointment(id) ON DELETE CASCADE,
    type           varchar(40) NOT NULL,
    language       varchar(5) NOT NULL DEFAULT 'en'
                   CHECK (language IN ('en','ar')),
    message        text,
    sent_at        timestamptz,
    status         varchar(20) NOT NULL DEFAULT 'PENDING'
                   CHECK (status IN ('PENDING','SENT','FAILED'))
);
CREATE INDEX idx_notification_user ON notification(user_id);

CREATE TABLE activity_log (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              uuid REFERENCES user_account(id) ON DELETE SET NULL,
    attempted_identifier varchar(255),
    action               varchar(60) NOT NULL,
    entity_type          varchar(60),
    entity_id            uuid,
    ip_address           inet,
    created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_activity_log_created ON activity_log(created_at DESC);
CREATE INDEX idx_activity_log_user ON activity_log(user_id);
CREATE INDEX idx_activity_log_action ON activity_log(action);

CREATE TRIGGER trg_user_account_updated
    BEFORE UPDATE OF email, phone, password_hash, role, status, language_pref
    ON user_account
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_patient_updated BEFORE UPDATE ON patient
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_appointment_updated BEFORE UPDATE ON appointment
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_activity_log_immutable BEFORE UPDATE OR DELETE ON activity_log
    FOR EACH ROW EXECUTE FUNCTION activity_log_reject_mutation();
CREATE TRIGGER trg_treatment_record_immutable BEFORE UPDATE OR DELETE ON treatment_record
    FOR EACH ROW EXECUTE FUNCTION block_update_delete();
