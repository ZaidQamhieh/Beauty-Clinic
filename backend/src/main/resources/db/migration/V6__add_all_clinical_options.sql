INSERT INTO form_question_option (question_id, value, label, display_order)
SELECT q.id, v.value, v.label, v.position FROM form_question q
JOIN (VALUES
    ('allergies','LIDOCAINE','Lidocaine',50),
    ('allergies','FRAGRANCE','Fragrance',60),
    ('allergies','NICKEL','Nickel',70),
    ('allergies','IODINE','Iodine',80),
    ('medications','IMMUNOSUPPRESSANTS','Immunosuppressants',30),
    ('medications','ORAL_STEROIDS','Oral steroids',40),
    ('medications','HORMONAL_CONTRACEPTIVES','Hormonal contraceptives',50),
    ('medications','ANTIBIOTICS','Antibiotics',60),
    ('chronicConditions','ECZEMA','Eczema',30),
    ('chronicConditions','PSORIASIS','Psoriasis',40),
    ('chronicConditions','ROSACEA','Rosacea',50),
    ('chronicConditions','THYROID_DISORDER','Thyroid disorder',60),
    ('chronicConditions','AUTOIMMUNE','Autoimmune',70)
) AS v(field_key,value,label,position) ON v.field_key=q.field_key 
WHERE q.form_key='clinical-intake'
ON CONFLICT DO NOTHING;
