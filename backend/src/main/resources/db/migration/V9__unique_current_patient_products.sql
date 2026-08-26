-- A patient can have a product only once in the current routine.
-- Discontinued rows remain available as history and may be re-added.
WITH duplicate_rows AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY patient_user_id, product_id
               ORDER BY started_on NULLS LAST, id
           ) AS row_number
    FROM patient_product
    WHERE discontinued_on IS NULL AND NOT deleted
)
UPDATE patient_product
SET discontinued_on = COALESCE(started_on, CURRENT_DATE)
WHERE id IN (SELECT id FROM duplicate_rows WHERE row_number > 1);

CREATE UNIQUE INDEX uq_patient_product_current
    ON patient_product(patient_user_id, product_id)
    WHERE discontinued_on IS NULL AND NOT deleted;