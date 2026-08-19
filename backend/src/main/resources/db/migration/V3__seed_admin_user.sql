-- Seed a single admin account so the app can be logged into on a fresh
-- database. Login: admin@clinic.com / password123
--
-- This is dev/test convenience data, not a fixture the app depends on to run.
-- Change the password after first login, or delete this migration and manage
-- accounts through the API once you have a real admin.
INSERT INTO user_account (email, password_hash, first_name, last_name, role)
VALUES (
           'admin@clinic.com',
           '{bcrypt}$2b$10$KOaE8ynJfN5rPuf/xCvWiewicsgLHkiQvOmO/KVZJ4a1RkR9DBUjG',
           'Admin',
        'User',
           'ADMIN'
       )
    ON CONFLICT (email) WHERE NOT deleted DO NOTHING;