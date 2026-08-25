ALTER TABLE product RENAME COLUMN category TO name;

ALTER TABLE product
    ADD COLUMN image_url varchar(2048);

ALTER TABLE user_account
    ADD COLUMN image_url varchar(2048);
