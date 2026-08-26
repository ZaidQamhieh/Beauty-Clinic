-- Redesigns doctor_availability from 2 kinds (RECURRING/OVERRIDE) + an is_available
-- flag into 4 kinds with a fixed, implicit open/closed meaning each: REGULAR (the
-- weekly pattern), VACATION (whole days off, no time component), MODIFIED (hours
-- replaced for a date range), EXTRA_DAY (an extra window, but only ever a fallback
-- for a day that would otherwise resolve to nothing - see DoctorAvailabilityService).
-- There is no longer a standalone closure/break row: gaps within a day are just
-- multiple REGULAR/MODIFIED/EXTRA_DAY slots.

-- Constraint names on this table were never given explicit names except
-- doctor_availability_shape, so drop every CHECK on it programmatically rather than
-- guess Postgres's auto-generated names.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT conname FROM pg_constraint
        WHERE conrelid = 'doctor_availability'::regclass
          AND contype = 'c'
    LOOP
        EXECUTE format('ALTER TABLE doctor_availability DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;

-- VACATION carries no time window - drop the NOT NULL constraints before the
-- data conversion below needs to null them out for converted VACATION rows.
ALTER TABLE doctor_availability ALTER COLUMN start_time DROP NOT NULL;
ALTER TABLE doctor_availability ALTER COLUMN end_time DROP NOT NULL;

-- Data conversion, before the new stricter constraints are installed.
-- A closure/break modeled as a standalone unavailable RECURRING row no longer exists
-- as a concept - multiple slots already cover the same need.
DELETE FROM doctor_availability WHERE kind = 'RECURRING' AND is_available = false;

UPDATE doctor_availability SET kind = 'REGULAR' WHERE kind = 'RECURRING';
UPDATE doctor_availability SET kind = 'MODIFIED' WHERE kind = 'OVERRIDE' AND is_available = true;
UPDATE doctor_availability
   SET kind = 'VACATION', start_time = NULL, end_time = NULL
 WHERE kind = 'OVERRIDE' AND is_available = false;

ALTER TABLE doctor_availability DROP COLUMN is_available;

ALTER TABLE doctor_availability ADD CONSTRAINT doctor_availability_kind_check
    CHECK (kind IN ('REGULAR','VACATION','MODIFIED','EXTRA_DAY'));

ALTER TABLE doctor_availability ADD CONSTRAINT doctor_availability_day_of_week_check
    CHECK (day_of_week IN ('SUNDAY','MONDAY','TUESDAY','WEDNESDAY',
                           'THURSDAY','FRIDAY','SATURDAY'));

ALTER TABLE doctor_availability ADD CONSTRAINT doctor_availability_window_ordered
    CHECK (start_time IS NULL OR end_time IS NULL OR end_time > start_time);

ALTER TABLE doctor_availability ADD CONSTRAINT doctor_availability_min_duration
    CHECK (start_time IS NULL OR end_time IS NULL
           OR end_time - start_time >= interval '30 minutes');

ALTER TABLE doctor_availability ADD CONSTRAINT doctor_availability_effective_range
    CHECK (effective_to IS NULL OR effective_to >= effective_from);

-- Field shape per kind: REGULAR needs a weekday and a window; VACATION is a bare
-- date range; MODIFIED/EXTRA_DAY need a window but no weekday. Every kind but
-- REGULAR is a dated exception, so effective_to is required for those three.
ALTER TABLE doctor_availability ADD CONSTRAINT doctor_availability_shape CHECK (
    (kind = 'REGULAR'   AND day_of_week IS NOT NULL AND start_time IS NOT NULL AND end_time IS NOT NULL)
 OR (kind = 'VACATION'  AND day_of_week IS NULL      AND start_time IS NULL     AND end_time IS NULL     AND effective_to IS NOT NULL)
 OR (kind = 'MODIFIED'  AND day_of_week IS NULL      AND start_time IS NOT NULL AND end_time IS NOT NULL AND effective_to IS NOT NULL)
 OR (kind = 'EXTRA_DAY' AND day_of_week IS NULL      AND start_time IS NOT NULL AND end_time IS NOT NULL AND effective_to IS NOT NULL)
);
