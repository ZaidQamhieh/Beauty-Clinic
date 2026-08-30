-- Baseline for the session-based clinic schema.
--
-- An appointment is a visit. What actually happens during it lives in
-- appointment_session rows: one per treatment, each with its own practitioner,
-- its own time window and its own price. That is why the practitioner is not on
-- the appointment - a single visit can span two treatments by two people.
--
-- Enumerations are varchar with a CHECK rather than native Postgres enum types.
-- ALTER TYPE ... ADD VALUE cannot run in the same transaction that uses the new
-- value, which fights Flyway, and Postgres can never remove an enum value. A
-- CHECK is edited freely in a later migration.

-- btree_gist lets the session overlap constraint mix uuid = with range &&.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION block_update_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% is insert-only; % is not permitted', TG_TABLE_NAME, TG_OP;
END;
$$;

-- ─── Identity ───────────────────────────────────────────────────────────────

-- One row per person, whatever their role. A doctor is a user_account with role
-- DOCTOR plus a doctor_profile; a patient is one with a patient_profile.
--
-- password_hash is nullable on purpose: reception registers walk-ins who have
-- never logged in, and those accounts sit at status INVITED until claimed.
CREATE TABLE user_account (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email              varchar(255) NOT NULL,
    phone              varchar(30),
    password_hash      varchar(255),
    first_name         varchar(100) NOT NULL,
    last_name          varchar(100) NOT NULL,
    date_of_birth      date,
    gender             varchar(20)
                       CHECK (gender IN ('MALE','FEMALE','OTHER')),
    role               varchar(30) NOT NULL
                       CHECK (role IN ('PATIENT','RECEPTIONIST','DOCTOR','ADMIN')),
    status             varchar(20) NOT NULL DEFAULT 'ACTIVE'
                       CHECK (status IN ('ACTIVE','INVITED','DEACTIVATED')),
    failed_login_count integer NOT NULL DEFAULT 0,
    lockout_strikes    integer NOT NULL DEFAULT 0,
    locked_until       timestamptz,
    deleted            boolean NOT NULL DEFAULT false,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    -- An account with no password has never been claimed and cannot log in.
    CONSTRAINT user_account_credentials CHECK (
        password_hash IS NOT NULL OR status = 'INVITED'
    )
);

-- Scoped to live rows: a soft-deleted account must not hold its email forever.
CREATE UNIQUE INDEX uq_user_account_email ON user_account(email) WHERE NOT deleted;
CREATE UNIQUE INDEX uq_user_account_phone ON user_account(phone) WHERE NOT deleted;
CREATE INDEX idx_user_account_role ON user_account(role) WHERE NOT deleted;

-- Patient search scans. No index yet: it matches lower(first_name) and
-- lower(last_name) separately, so add one tuned to that once there is data
-- to measure against.

CREATE TABLE refresh_token (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    token_hash varchar(255) NOT NULL,
    issued_at  timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    deleted    boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX uq_refresh_token_hash ON refresh_token(token_hash) WHERE NOT deleted;
CREATE INDEX idx_refresh_token_user ON refresh_token(user_id);

-- ─── Profiles ───────────────────────────────────────────────────────────────

-- Clinical intake, kept off user_account so reception can read names and phone
-- numbers without also seeing skin type, pregnancy status or medication lists.
CREATE TABLE patient_profile (
    user_id               uuid PRIMARY KEY REFERENCES user_account(id) ON DELETE RESTRICT,
    pregnant_breastfeeding boolean NOT NULL DEFAULT false,
    skin_type             varchar(20)
                          CHECK (skin_type IN ('NORMAL','DRY','OILY','COMBINATION','SENSITIVE')),
    smoking_status        varchar(20)
                          CHECK (smoking_status IN ('NEVER','FORMER','CURRENT')),
    allergies             text[] NOT NULL DEFAULT '{}',
    medications           text[] NOT NULL DEFAULT '{}',
    chronic_conditions    text[] NOT NULL DEFAULT '{}',
    deleted               boolean NOT NULL DEFAULT false,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patient_profile_allergies CHECK (allergies <@ ARRAY[
        'NUTS','LATEX','PENICILLIN','SULFA','LIDOCAINE','FRAGRANCE','NICKEL','IODINE'
    ]::text[]),
    CONSTRAINT patient_profile_medications CHECK (medications <@ ARRAY[
        'ISOTRETINOIN','ANTICOAGULANTS','IMMUNOSUPPRESSANTS','ORAL_STEROIDS',
        'HORMONAL_CONTRACEPTIVES','ANTIBIOTICS'
    ]::text[]),
    CONSTRAINT patient_profile_conditions CHECK (chronic_conditions <@ ARRAY[
        'DIABETES','HYPERTENSION','ECZEMA','PSORIASIS','ROSACEA',
        'THYROID_DISORDER','AUTOIMMUNE'
    ]::text[])
);

CREATE TABLE doctor_profile (
    user_id             uuid PRIMARY KEY REFERENCES user_account(id) ON DELETE RESTRICT,
    specializations     text[] NOT NULL DEFAULT '{}',
    years_of_experience integer CHECK (years_of_experience >= 0),
    deleted             boolean NOT NULL DEFAULT false,
    CONSTRAINT doctor_profile_specializations CHECK (specializations <@ ARRAY[
        'DERMATOLOGY','COSMETIC_DERMATOLOGY','LASER_THERAPY',
        'INJECTABLES','AESTHETIC_MEDICINE'
    ]::text[])
);

-- ─── Availability ───────────────────────────────────────────────────────────

-- Two kinds of row in one table. RECURRING carries the weekly pattern and uses
-- day_of_week; OVERRIDE is a dated one-off - a holiday, a sick day, an extra
-- shift - and uses effective_from/effective_to. An OVERRIDE always wins over a
-- RECURRING row covering the same moment.
--
-- start_time and end_time are the clinic's local wall clock, resolved against
-- app.clinic.timezone. They are not UTC and not the server's zone.
CREATE TABLE doctor_availability (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_user_id uuid NOT NULL REFERENCES doctor_profile(user_id) ON DELETE CASCADE,
    kind           varchar(20) NOT NULL
                   CHECK (kind IN ('RECURRING','OVERRIDE')),
    day_of_week    varchar(10)
                   CHECK (day_of_week IN ('SUNDAY','MONDAY','TUESDAY','WEDNESDAY',
                                          'THURSDAY','FRIDAY','SATURDAY')),
    start_time     time NOT NULL,
    end_time       time NOT NULL,
    is_available   boolean NOT NULL DEFAULT true,
    effective_from date NOT NULL,
    effective_to   date,
    deleted        boolean NOT NULL DEFAULT false,
    CHECK (end_time > start_time),
    CHECK (effective_to IS NULL OR effective_to >= effective_from),
    -- A weekly rule needs the day it repeats on; a dated override does not.
    CONSTRAINT doctor_availability_shape CHECK (
        (kind = 'RECURRING' AND day_of_week IS NOT NULL)
     OR (kind = 'OVERRIDE'  AND day_of_week IS NULL)
    )
);
CREATE INDEX idx_doctor_availability_doctor ON doctor_availability(doctor_user_id)
    WHERE NOT deleted;

-- ─── Appointments ───────────────────────────────────────────────────────────

-- The visit. Who is treated and when they arrive; what is done to them lives in
-- appointment_session.
CREATE TABLE appointment (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_user_id         uuid NOT NULL REFERENCES patient_profile(user_id) ON DELETE RESTRICT,
    scheduled_at            timestamptz NOT NULL,
    -- Visit-level only. Whether the work was done is a property of the sessions,
    -- so an appointment whose sessions disagree has no contradictory state here.
    status                  varchar(20) NOT NULL DEFAULT 'BOOKED'
                            CHECK (status IN ('BOOKED','CANCELLED')),
    created_by_user_id      uuid REFERENCES user_account(id) ON DELETE SET NULL,
    replaces_appointment_id uuid REFERENCES appointment(id) ON DELETE SET NULL,
    cancelled_at            timestamptz,
    deleted                 boolean NOT NULL DEFAULT false,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_appointment_patient ON appointment(patient_user_id);
CREATE INDEX idx_appointment_status_scheduled ON appointment(status, scheduled_at);
-- A reschedule chain is linear: one appointment replaces at most one other.
CREATE UNIQUE INDEX uq_appointment_replaces ON appointment(replaces_appointment_id)
    WHERE replaces_appointment_id IS NOT NULL;

-- One treatment within a visit. price_charged and duration_minutes are copied in
-- at booking rather than read live, so changing the tariff never re-prices work
-- that has already happened.
CREATE TABLE appointment_session (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id       uuid NOT NULL REFERENCES appointment(id) ON DELETE RESTRICT,
    practitioner_user_id uuid NOT NULL REFERENCES doctor_profile(user_id) ON DELETE RESTRICT,
    category             varchar(30) NOT NULL
                         CHECK (category IN ('FACIAL','LASER','INJECTABLE','BODY','CONSULTATION')),
    treatment_name       varchar(60) NOT NULL
                         CHECK (treatment_name IN (
                             'HYDRAFACIAL','CHEMICAL_PEEL','MICRONEEDLING','DERMAPLANING',
                             'LASER_HAIR_REMOVAL','LASER_RESURFACING','IPL_PHOTOFACIAL',
                             'BOTOX','DERMAL_FILLER','MESOTHERAPY',
                             'BODY_CONTOURING','CONSULTATION')),
    price_charged        numeric(10,2) NOT NULL CHECK (price_charged >= 0),
    duration_minutes     integer NOT NULL CHECK (duration_minutes > 0),
    status               varchar(20) NOT NULL DEFAULT 'PLANNED'
                         CHECK (status IN ('PLANNED','COMPLETED','CANCELLED','NO_SHOW')),
    start_time           timestamptz NOT NULL,
    end_time             timestamptz NOT NULL,
    before_photo_key     varchar(500),
    after_photo_key      varchar(500),
    deleted              boolean NOT NULL DEFAULT false,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CHECK (end_time > start_time),
    -- Database-level guarantee: a practitioner cannot hold two overlapping
    -- sessions. Application code cannot enforce this against concurrent writes.
    CONSTRAINT session_no_practitioner_overlap EXCLUDE USING gist (
        practitioner_user_id WITH =,
        tstzrange(start_time, end_time) WITH &&
    ) WHERE (status <> 'CANCELLED' AND NOT deleted),
    -- And the patient is not in two chairs at once.
    CONSTRAINT session_no_patient_overlap EXCLUDE USING gist (
        appointment_id WITH =,
        tstzrange(start_time, end_time) WITH &&
    ) WHERE (status <> 'CANCELLED' AND NOT deleted)
);
CREATE INDEX idx_session_appointment ON appointment_session(appointment_id);
CREATE INDEX idx_session_practitioner_start ON appointment_session(practitioner_user_id, start_time);

-- ─── Clinical record ────────────────────────────────────────────────────────

-- Insert-only. A correction is a new row pointing at the one it replaces, so
-- what was originally written about a treatment can never be rewritten. The
-- live note for a session is the row in the chain nothing else amends.
CREATE TABLE session_record (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id       uuid NOT NULL REFERENCES appointment_session(id) ON DELETE RESTRICT,
    author_user_id   uuid NOT NULL REFERENCES doctor_profile(user_id) ON DELETE RESTRICT,
    note             text,
    skin_reaction    varchar(20)
                     CHECK (skin_reaction IN ('NONE','MILD','MODERATE','SEVERE')),
    follow_up_date   date,
    amends_record_id uuid UNIQUE REFERENCES session_record(id) ON DELETE RESTRICT,
    created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_session_record_session ON session_record(session_id);

-- ─── Products ───────────────────────────────────────────────────────────────

-- A reference catalogue of what the clinic recommends, not stock it sells.
-- A row is a brand and a product type, so "CeraVe moisturiser" is one row.
-- No soft delete: prescriptions and patient routines point here, and hiding a
-- row would make those historical records unreadable.
CREATE TABLE product (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand        varchar(60) NOT NULL
                 CHECK (brand IN ('CERAVE','LA_ROCHE_POSAY','SKINCEUTICALS',
                                  'OBAGI','ZO_SKIN_HEALTH','BIODERMA','AVENE')),
    product_type varchar(40) NOT NULL
                 CHECK (product_type IN ('CLEANSER','MOISTURIZER','SERUM','SUNSCREEN',
                                         'TONER','EXFOLIANT','MASK','RETINOID')),
    ingredients  text[] NOT NULL DEFAULT '{}',
    UNIQUE (brand, product_type),
    CONSTRAINT product_ingredients CHECK (ingredients <@ ARRAY[
        'RETINOL','NIACINAMIDE','SALICYLIC_ACID','HYALURONIC_ACID','VITAMIN_C',
        'GLYCOLIC_ACID','BENZOYL_PEROXIDE','AZELAIC_ACID','CERAMIDES','ZINC_OXIDE'
    ]::text[])
);

-- What was recommended at a given session. Immutable with its parent record.
CREATE TABLE prescription_product (
    session_record_id uuid NOT NULL REFERENCES session_record(id) ON DELETE RESTRICT,
    product_id        uuid NOT NULL REFERENCES product(id) ON DELETE RESTRICT,
    PRIMARY KEY (session_record_id, product_id)
);
CREATE INDEX idx_prescription_product_product ON prescription_product(product_id);

-- What the patient is actually using now, which is not the same question.
-- source separates what the clinic put them on from what they turned up already
-- using, and discontinued_on is what stops the list going stale.
CREATE TABLE patient_product (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_user_id        uuid NOT NULL REFERENCES patient_profile(user_id) ON DELETE CASCADE,
    product_id             uuid NOT NULL REFERENCES product(id) ON DELETE RESTRICT,
    source                 varchar(20) NOT NULL
                           CHECK (source IN ('PRESCRIBED','PATIENT_OWN')),
    started_on             date,
    discontinued_on        date,
    added_by_user_id       uuid NOT NULL REFERENCES user_account(id) ON DELETE RESTRICT,
    discontinued_by_user_id uuid,
    deleted                boolean NOT NULL DEFAULT false,
    CHECK (discontinued_on IS NULL OR started_on IS NULL OR discontinued_on >= started_on)
);
CREATE INDEX idx_patient_product_patient ON patient_product(patient_user_id)
    WHERE NOT deleted;

-- ─── Audit ──────────────────────────────────────────────────────────────────

-- Append-only. attempted_identifier holds whatever a failed login typed, which
-- is the only record of the attempt when no account matches and user_id is null.
CREATE TABLE activity_log (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              uuid REFERENCES user_account(id) ON DELETE SET NULL,
    patient_user_id      uuid REFERENCES patient_profile(user_id) ON DELETE SET NULL,
    attempted_identifier varchar(255),
    action               varchar(60) NOT NULL,
    entity_type          varchar(60),
    entity_id            uuid,
    old_values           jsonb,
    new_values           jsonb,
    created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_activity_log_created ON activity_log(created_at DESC);
CREATE INDEX idx_activity_log_user ON activity_log(user_id);
CREATE INDEX idx_activity_log_patient ON activity_log(patient_user_id);
CREATE INDEX idx_activity_log_action ON activity_log(action);

-- ─── Triggers ───────────────────────────────────────────────────────────────

-- Scoped so login throttling does not touch updated_at.
CREATE TRIGGER trg_user_account_updated
    BEFORE UPDATE OF email, phone, password_hash, first_name, last_name,
                     date_of_birth, gender, role, status, deleted
    ON user_account
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_patient_profile_updated BEFORE UPDATE ON patient_profile
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_appointment_updated BEFORE UPDATE ON appointment
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_appointment_session_updated BEFORE UPDATE ON appointment_session
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_session_record_immutable BEFORE UPDATE OR DELETE ON session_record
    FOR EACH ROW EXECUTE FUNCTION block_update_delete();
CREATE TRIGGER trg_prescription_product_immutable
    BEFORE UPDATE OR DELETE ON prescription_product
    FOR EACH ROW EXECUTE FUNCTION block_update_delete();
CREATE TRIGGER trg_activity_log_immutable BEFORE UPDATE OR DELETE ON activity_log
    FOR EACH ROW EXECUTE FUNCTION block_update_delete();

-- Clinical notes are insert-only and must stay reachable, so a session carrying
-- them cannot be soft-deleted out from under the record that references it.
CREATE FUNCTION block_soft_delete_with_records() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM session_record WHERE session_id = NEW.id) THEN
        RAISE EXCEPTION 'session % has clinical records and cannot be deleted', NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_session_soft_delete_guard
    BEFORE UPDATE OF deleted ON appointment_session
    FOR EACH ROW WHEN (NEW.deleted AND NOT OLD.deleted)
    EXECUTE FUNCTION block_soft_delete_with_records();
