-- Activity log gains a category, a real correlation column, and a purge path.

ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS category       varchar(20);
ALTER TABLE activity_log ADD COLUMN IF NOT EXISTS correlation_id uuid;

-- Backfill needs the immutability trigger out of the way.
DROP TRIGGER IF EXISTS trg_activity_log_immutable ON activity_log;

UPDATE activity_log SET category = CASE action
    WHEN 'CLINICAL_PROFILE_UPDATED'      THEN 'CLINICAL'
    WHEN 'PATIENT_DEMOGRAPHICS_UPDATED'  THEN 'CLINICAL'
    WHEN 'SESSION_RECORD_CREATED'        THEN 'CLINICAL'
    WHEN 'SESSION_RECORD_AMENDED'        THEN 'CLINICAL'
    WHEN 'CLINICAL_PROFILE_VIEWED'       THEN 'CLINICAL'
    WHEN 'CLINICAL_HISTORY_VIEWED'       THEN 'CLINICAL'
    WHEN 'SESSION_RECORDS_VIEWED'        THEN 'CLINICAL'
    WHEN 'APPOINTMENT_BOOKED'            THEN 'CLINICAL'
    WHEN 'APPOINTMENT_RESCHEDULED'       THEN 'CLINICAL'
    WHEN 'APPOINTMENT_CANCELLED'         THEN 'CLINICAL'
    WHEN 'APPOINTMENT_SESSIONS_ADDED'    THEN 'CLINICAL'
    WHEN 'SESSION_SCHEDULED'             THEN 'CLINICAL'
    WHEN 'SESSION_CANCELLED'             THEN 'CLINICAL'
    WHEN 'SESSION_COMPLETED'             THEN 'CLINICAL'
    WHEN 'SESSION_NO_SHOW'               THEN 'CLINICAL'
    WHEN 'PATIENT_PRODUCT_ADDED'         THEN 'CLINICAL'
    WHEN 'PATIENT_PRODUCT_DISCONTINUED'  THEN 'CLINICAL'
    WHEN 'ACCOUNT_REGISTERED'            THEN 'ADMIN'
    WHEN 'ACCOUNT_CREATED'               THEN 'ADMIN'
    WHEN 'ACCOUNT_UPDATED'               THEN 'ADMIN'
    WHEN 'ACCOUNT_DELETED'               THEN 'ADMIN'
    WHEN 'PASSWORD_CHANGED'              THEN 'ADMIN'
    WHEN 'PROFILE_UPDATED'               THEN 'ADMIN'
    WHEN 'PATIENT_REGISTERED_BY_STAFF'   THEN 'ADMIN'
    WHEN 'DOCTOR_CREATED'                THEN 'ADMIN'
    WHEN 'DOCTOR_UPDATED'                THEN 'ADMIN'
    WHEN 'DOCTOR_DELETED'                THEN 'ADMIN'
    WHEN 'AVAILABILITY_ADDED'            THEN 'ADMIN'
    WHEN 'AVAILABILITY_REMOVED'          THEN 'ADMIN'
    WHEN 'PRODUCT_CREATED'               THEN 'ADMIN'
    WHEN 'PRODUCT_UPDATED'               THEN 'ADMIN'
    WHEN 'PRODUCT_DELETED'               THEN 'ADMIN'
    WHEN 'FORM_QUESTION_CREATED'         THEN 'ADMIN'
    WHEN 'FORM_QUESTION_UPDATED'         THEN 'ADMIN'
    WHEN 'FORM_QUESTION_ACTIVATED'       THEN 'ADMIN'
    WHEN 'FORM_QUESTION_DEACTIVATED'     THEN 'ADMIN'
    WHEN 'LOGIN_FAILED'                  THEN 'SECURITY'
    WHEN 'PERMISSION_DENIED'             THEN 'SECURITY'
    WHEN 'ACCOUNT_LOCKED'                THEN 'SECURITY'
    WHEN 'AUTH_RATE_LIMITED'             THEN 'SECURITY'
    WHEN 'STALE_SESSION_REJECTED'        THEN 'SECURITY'
    WHEN 'ROLE_CHANGE_REJECTED'          THEN 'SECURITY'
    WHEN 'DISABLED_ACCOUNT_REJECTED'     THEN 'SECURITY'
    WHEN 'REFRESH_TOKEN_REJECTED'        THEN 'SECURITY'
    ELSE 'LEGACY'
END;

-- The id was hidden in the payload; give it a column.
UPDATE activity_log
   SET correlation_id = (new_values ->> 'correlationId')::uuid
 WHERE new_values ? 'correlationId';

UPDATE activity_log
   SET new_values = NULLIF(new_values - 'correlationId', '{}'::jsonb)
 WHERE new_values ? 'correlationId';

ALTER TABLE activity_log ALTER COLUMN category SET NOT NULL;

-- Still insert-only, except a purge that says so.
CREATE OR REPLACE FUNCTION block_activity_log_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' AND current_setting('app.purge', true) = 'on' THEN
        RETURN OLD;
    END IF;

    RAISE EXCEPTION 'activity_log is insert-only; % is not permitted', TG_OP;
END;
$$;

CREATE TRIGGER trg_activity_log_immutable BEFORE UPDATE OR DELETE ON activity_log
    FOR EACH ROW EXECUTE FUNCTION block_activity_log_mutation();

CREATE INDEX IF NOT EXISTS idx_activity_log_category ON activity_log(category);
CREATE INDEX IF NOT EXISTS idx_activity_log_correlation ON activity_log(correlation_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_patient_created ON activity_log(patient_user_id, created_at DESC);

-- Answers the view dedup lookup.
CREATE INDEX IF NOT EXISTS idx_activity_log_view_dedup
    ON activity_log(user_id, patient_user_id, action, created_at DESC);
