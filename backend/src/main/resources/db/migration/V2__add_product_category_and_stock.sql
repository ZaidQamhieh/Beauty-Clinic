ALTER TABLE product
    ADD COLUMN category varchar(60) NOT NULL DEFAULT 'Uncategorized',
    ADD COLUMN stock_quantity integer NOT NULL DEFAULT 0,
    ADD CONSTRAINT product_stock_nonnegative CHECK (stock_quantity >= 0);

ALTER TABLE product ALTER COLUMN category DROP DEFAULT;
