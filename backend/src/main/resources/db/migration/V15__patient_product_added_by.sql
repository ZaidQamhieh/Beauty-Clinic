-- Every routine entry records who added it. Already present where V11/V12 ran.
ALTER TABLE patient_product ADD COLUMN IF NOT EXISTS added_by_user_id uuid;

-- Rows that predate the column belong to the patient.
UPDATE patient_product
   SET added_by_user_id = patient_user_id
 WHERE added_by_user_id IS NULL;

ALTER TABLE patient_product ALTER COLUMN added_by_user_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint c
          JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
         WHERE c.conrelid = 'patient_product'::regclass
           AND c.contype = 'f'
           AND a.attname = 'added_by_user_id'
    ) THEN
        ALTER TABLE patient_product
            ADD CONSTRAINT fk_patient_product_added_by
            FOREIGN KEY (added_by_user_id) REFERENCES user_account(id) ON DELETE RESTRICT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_patient_product_added_by ON patient_product(added_by_user_id);
