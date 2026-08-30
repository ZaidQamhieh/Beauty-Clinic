ALTER TABLE patient_product
    ADD COLUMN IF NOT EXISTS discontinued_by_user_id UUID;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint c
          JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
         WHERE c.conrelid = 'patient_product'::regclass
           AND c.contype = 'f'
           AND a.attname = 'discontinued_by_user_id'
    ) THEN
        ALTER TABLE patient_product
            ADD CONSTRAINT fk_patient_product_discontinued_by
            FOREIGN KEY (discontinued_by_user_id) REFERENCES user_account(id) ON DELETE RESTRICT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_patient_product_discontinued_by ON patient_product(discontinued_by_user_id);
