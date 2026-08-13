-- session_no_patient_overlap was keyed on appointment_id, so it only ever stopped a
-- patient double-booking inside one visit. Two separate visits at the same time passed
-- the database and were caught by application code alone, which cannot hold against
-- concurrent writes. Keying the constraint on the patient closes that, and subsumes the
-- old rule: every session in one visit shares its patient.

-- A gist exclusion cannot reach through a join, so the patient is carried on the row.
ALTER TABLE appointment_session ADD COLUMN patient_user_id uuid;

UPDATE appointment_session s
SET patient_user_id = a.patient_user_id
FROM appointment a
WHERE a.id = s.appointment_id;

ALTER TABLE appointment_session ALTER COLUMN patient_user_id SET NOT NULL;

-- The FK target of the composite key below; id alone is already unique as the primary key.
ALTER TABLE appointment ADD CONSTRAINT uq_appointment_id_patient UNIQUE (id, patient_user_id);

-- Declarative, so the copied patient can never disagree with the visit's own.
ALTER TABLE appointment_session
    ADD CONSTRAINT session_patient_matches_visit
    FOREIGN KEY (appointment_id, patient_user_id)
    REFERENCES appointment (id, patient_user_id) ON DELETE RESTRICT;

-- Same name kept: AppointmentSessionService matches on it to name the lost slot.
ALTER TABLE appointment_session DROP CONSTRAINT session_no_patient_overlap;
ALTER TABLE appointment_session
    ADD CONSTRAINT session_no_patient_overlap EXCLUDE USING gist (
        patient_user_id WITH =,
        tstzrange(start_time, end_time) WITH &&
    ) WHERE (status <> 'CANCELLED' AND NOT deleted);

CREATE INDEX idx_session_patient_start ON appointment_session(patient_user_id, start_time);
