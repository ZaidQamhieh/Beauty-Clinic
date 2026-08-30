ALTER TABLE patient_product
    ADD COLUMN IF NOT EXISTS discontinued_by_user_id UUID;
