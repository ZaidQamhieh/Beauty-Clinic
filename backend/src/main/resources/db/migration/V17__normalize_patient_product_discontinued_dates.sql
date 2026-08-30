-- Legacy rows can have a discontinuation date earlier than their start date when
-- a patient routine was ended before the date was normalized. Keep the historical
-- record consistent with the CHECK constraint and the current routine rules.
UPDATE patient_product
SET discontinued_on = started_on
WHERE discontinued_on IS NOT NULL
  AND started_on IS NOT NULL
  AND discontinued_on < started_on;
