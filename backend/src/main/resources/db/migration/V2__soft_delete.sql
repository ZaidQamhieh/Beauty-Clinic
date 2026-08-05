-- Soft delete: a delete becomes UPDATE ... SET deleted = true, and every query
-- Hibernate runs against these entities gains an implicit "deleted = false".
--
-- treatment_record is deliberately excluded: it already carries a stronger
-- guarantee than soft delete. trg_treatment_record_immutable blocks UPDATE and
-- DELETE both, and a correction is a new row via amends_record_id. Adding a
-- soft-delete column would only give that trigger an UPDATE to reject.
ALTER TABLE user_account   ADD COLUMN deleted boolean NOT NULL DEFAULT false;
ALTER TABLE refresh_token  ADD COLUMN deleted boolean NOT NULL DEFAULT false;
ALTER TABLE doctor         ADD COLUMN deleted boolean NOT NULL DEFAULT false;
ALTER TABLE service        ADD COLUMN deleted boolean NOT NULL DEFAULT false;
ALTER TABLE patient        ADD COLUMN deleted boolean NOT NULL DEFAULT false;
ALTER TABLE appointment    ADD COLUMN deleted boolean NOT NULL DEFAULT false;
ALTER TABLE doctor_service ADD COLUMN deleted boolean NOT NULL DEFAULT false;

-- Every uniqueness rule below was written when a delete removed the row. A
-- soft-deleted row still occupies the table, so each one has to be re-scoped to
-- live rows or a deleted account would hold its email address forever.
ALTER TABLE user_account DROP CONSTRAINT user_account_email_key;
CREATE UNIQUE INDEX uq_user_account_email ON user_account(email) WHERE NOT deleted;

ALTER TABLE user_account DROP CONSTRAINT user_account_phone_key;
CREATE UNIQUE INDEX uq_user_account_phone ON user_account(phone) WHERE NOT deleted;

ALTER TABLE doctor DROP CONSTRAINT doctor_license_number_key;
CREATE UNIQUE INDEX uq_doctor_license_number ON doctor(license_number) WHERE NOT deleted;

ALTER TABLE patient DROP CONSTRAINT patient_user_id_key;
CREATE UNIQUE INDEX uq_patient_user_id ON patient(user_id) WHERE NOT deleted;

ALTER TABLE refresh_token DROP CONSTRAINT refresh_token_token_hash_key;
CREATE UNIQUE INDEX uq_refresh_token_hash ON refresh_token(token_hash) WHERE NOT deleted;

-- Same problem on the join table, but as a primary key. Hibernate re-adds a
-- previously removed pair with a fresh INSERT rather than clearing the flag, so
-- the composite key has to become a live-rows-only unique index or re-offering a
-- treatment a doctor once dropped would collide with the tombstone.
ALTER TABLE doctor_service DROP CONSTRAINT doctor_service_pkey;
CREATE UNIQUE INDEX uq_doctor_service_active
    ON doctor_service(doctor_id, service_id) WHERE NOT deleted;

-- The double-booking guard predates soft delete and would keep reserving the
-- slot of a deleted appointment: the application, which now filters those rows
-- out, would offer the slot as free and then fail to insert into it.
ALTER TABLE appointment DROP CONSTRAINT appointment_no_double_booking;
ALTER TABLE appointment ADD CONSTRAINT appointment_no_double_booking EXCLUDE USING gist (
    doctor_id WITH =,
    tstzrange(start_time, end_time) WITH &&
) WHERE (status <> 'CANCELLED' AND NOT deleted);

-- Clinical notes are insert-only and must stay reachable. They are read through
-- their appointment, so soft-deleting the appointment would hide notes the
-- treatment_record trigger refuses to let anyone delete outright.
CREATE FUNCTION block_soft_delete_with_records() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM treatment_record WHERE appointment_id = NEW.id) THEN
        RAISE EXCEPTION 'appointment % has treatment records and cannot be deleted', NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointment_soft_delete_guard
    BEFORE UPDATE OF deleted ON appointment
    FOR EACH ROW WHEN (NEW.deleted AND NOT OLD.deleted)
    EXECUTE FUNCTION block_soft_delete_with_records();
