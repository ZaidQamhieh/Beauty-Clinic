CREATE TABLE login_lockouts (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier       varchar(255) NOT NULL UNIQUE,
    failed_attempts  integer NOT NULL DEFAULT 0,
    lockout_strikes  integer NOT NULL DEFAULT 0,
    locked_until     timestamptz
);
