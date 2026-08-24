-- Test catalogue data for exercising product list, edit, and stock states.
-- Remove these test records after finishing product testing.
-- Safe to run more than once because brand + product_type is unique.
INSERT INTO product (brand, product_type, category, stock_quantity, ingredients)
VALUES
    ('CERAVE', 'CLEANSER', 'Facial Cleansers', 24, ARRAY['CERAMIDES', 'SALICYLIC_ACID']),
    ('LA_ROCHE_POSAY', 'MOISTURIZER', 'Hydration', 8, ARRAY['CERAMIDES', 'HYALURONIC_ACID']),
    ('SKINCEUTICALS', 'SERUM', 'Antioxidant Serums', 3, ARRAY['VITAMIN_C']),
    ('OBAGI', 'SUNSCREEN', 'Daily Protection', 0, ARRAY['ZINC_OXIDE']),
    ('BIODERMA', 'MASK', 'Treatment Masks', 15, ARRAY['NIACINAMIDE']),
    ('AVENE', 'TONER', 'Skin Preparation', 6, ARRAY['GLYCOLIC_ACID'])
ON CONFLICT (brand, product_type) DO NOTHING;
