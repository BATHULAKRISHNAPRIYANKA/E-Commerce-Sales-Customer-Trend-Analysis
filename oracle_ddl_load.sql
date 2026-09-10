-- =====================================================================
-- E-COMMERCE 100K PROJECT - ORACLE SCHEMA & LOAD SCRIPTS
-- Tables: CUSTOMERS, PRODUCTS, ORDERS (cleaned)
-- =====================================================================

-- 1. DROP (safe re-run during dev)
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE ORDERS PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE PRODUCTS PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE CUSTOMERS PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- 2. DDL -----------------------------------------------------------

CREATE TABLE CUSTOMERS (
    CUSTOMER_ID       NUMBER          NOT NULL,
    CUSTOMER_NAME     VARCHAR2(100)   NOT NULL,
    CITY              VARCHAR2(50)    NOT NULL,
    CUSTOMER_SEGMENT  VARCHAR2(20)    NOT NULL,
    CONSTRAINT PK_CUSTOMERS PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT CK_CUST_SEGMENT CHECK (CUSTOMER_SEGMENT IN ('New','Returning','VIP'))
);

CREATE TABLE PRODUCTS (
    PRODUCT_ID        NUMBER          NOT NULL,
    SKU               VARCHAR2(20)    NOT NULL,
    CATEGORY          VARCHAR2(50)    NOT NULL,
    UNIT_PRICE        NUMBER(10,2)    NOT NULL,
    BRAND             VARCHAR2(30)    NOT NULL,
    CONSTRAINT PK_PRODUCTS PRIMARY KEY (PRODUCT_ID),
    CONSTRAINT UQ_PRODUCTS_SKU UNIQUE (SKU),
    CONSTRAINT CK_UNIT_PRICE CHECK (UNIT_PRICE > 0)
);

CREATE TABLE ORDERS (
    ORDER_ID              NUMBER          NOT NULL,
    ORDER_DATE            DATE            NOT NULL,
    CUSTOMER_ID           NUMBER          NOT NULL,
    PRODUCT_ID            NUMBER          NOT NULL,
    QUANTITY              NUMBER(5)       NOT NULL,
    ORDER_VALUE           NUMBER(10,2)    NOT NULL,
    ORDER_STATUS          VARCHAR2(20)    NOT NULL,
    PAYMENT_METHOD        VARCHAR2(20)    NOT NULL,
    RATING                NUMBER(1),
    ORDER_YEAR            NUMBER(4),
    ORDER_MONTH           NUMBER(2),
    ORDER_YEAR_MONTH      VARCHAR2(7),
    COMPUTED_VALUE        NUMBER(12,2),
    VALUE_VARIANCE        NUMBER(12,2),
    VALUE_VARIANCE_PCT    NUMBER(8,4),
    IS_DELIVERED_RATING   CHAR(1),
    IS_ORDERVALUE_OUTLIER CHAR(1),
    IS_PARTIAL_PERIOD     CHAR(1),
    CONSTRAINT PK_ORDERS PRIMARY KEY (ORDER_ID),
    CONSTRAINT FK_ORD_CUSTOMER FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
    CONSTRAINT FK_ORD_PRODUCT  FOREIGN KEY (PRODUCT_ID)  REFERENCES PRODUCTS(PRODUCT_ID),
    CONSTRAINT CK_ORD_STATUS   CHECK (ORDER_STATUS IN ('Delivered','Shipped','Returned','Cancelled')),
    CONSTRAINT CK_ORD_RATING   CHECK (RATING BETWEEN 1 AND 5)
);

-- helpful indexes for the analysis workload
CREATE INDEX IX_ORDERS_CUST   ON ORDERS(CUSTOMER_ID);
CREATE INDEX IX_ORDERS_PROD   ON ORDERS(PRODUCT_ID);
CREATE INDEX IX_ORDERS_DATE   ON ORDERS(ORDER_DATE);
CREATE INDEX IX_ORDERS_STATUS ON ORDERS(ORDER_STATUS);

COMMIT;

-- =====================================================================
-- 3. LOAD OPTIONS
-- =====================================================================
-- OPTION A: SQL*Loader (recommended for 100K+ rows) -------------------
-- Run from OS shell (not SQL*Plus):
--   sqlldr userid=ecom_user/pwd@orclpdb control=load_orders.ctl log=orders.log
-- See the matching .ctl files exported alongside this script:
--   load_customers.ctl, load_products.ctl, load_orders.ctl
--
-- OPTION B: External Table (query CSV directly without loading) ------
-- CREATE TABLE ORDERS_EXT (
--     ORDER_ID NUMBER, ORDER_DATE DATE, CUSTOMER_ID NUMBER, PRODUCT_ID NUMBER,
--     QUANTITY NUMBER, ORDER_VALUE NUMBER, ORDER_STATUS VARCHAR2(20),
--     PAYMENT_METHOD VARCHAR2(20), RATING NUMBER
-- )
-- ORGANIZATION EXTERNAL (
--     TYPE ORACLE_LOADER
--     DEFAULT DIRECTORY DATA_DIR
--     ACCESS PARAMETERS (
--         RECORDS DELIMITED BY NEWLINE
--         SKIP 1
--         FIELDS TERMINATED BY ','
--         OPTIONALLY ENCLOSED BY '"'
--         MISSING FIELD VALUES ARE NULL
--     )
--     LOCATION ('Orders_cleaned.csv')
-- )
-- REJECT LIMIT UNLIMITED;
--
-- OPTION C: Small/dev-friendly - Python cx_Oracle / oracledb executemany
-- (script provided separately: load_to_oracle.py) --------------------
