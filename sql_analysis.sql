-- =====================================================================
-- E-COMMERCE 100K PROJECT - SQL BUSINESS ANALYSIS
-- Target: Oracle Database (tables from oracle_ddl_load.sql)
-- Organized by business question. Each query is runnable standalone.
-- =====================================================================


-- =====================================================================
-- SECTION A: REVENUE & SALES OVERVIEW
-- =====================================================================

-- A1. Headline KPIs
SELECT
    COUNT(*)                         AS total_orders,
    ROUND(SUM(ORDER_VALUE),2)        AS total_revenue,
    ROUND(AVG(ORDER_VALUE),2)        AS avg_order_value,
    COUNT(DISTINCT CUSTOMER_ID)      AS active_customers,
    COUNT(DISTINCT PRODUCT_ID)       AS active_products
FROM ORDERS;

-- A2. Revenue by order status (delivered vs shipped vs returned vs cancelled)
SELECT ORDER_STATUS,
       COUNT(*)                      AS order_count,
       ROUND(SUM(ORDER_VALUE),2)     AS revenue,
       ROUND(AVG(ORDER_VALUE),2)     AS avg_value,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS pct_of_orders
FROM ORDERS
GROUP BY ORDER_STATUS
ORDER BY revenue DESC;

-- A3. Monthly revenue trend (excludes the partial final month)
SELECT ORDER_YEAR_MONTH,
       COUNT(*)                      AS orders,
       ROUND(SUM(ORDER_VALUE),2)     AS revenue,
       ROUND(AVG(ORDER_VALUE),2)     AS avg_order_value
FROM ORDERS
WHERE IS_PARTIAL_PERIOD = 'N'
GROUP BY ORDER_YEAR_MONTH
ORDER BY ORDER_YEAR_MONTH;

-- A4. Month-over-month growth rate (uses LAG window function)
SELECT ORDER_YEAR_MONTH,
       revenue,
       ROUND(100*(revenue - LAG(revenue) OVER (ORDER BY ORDER_YEAR_MONTH))
             / LAG(revenue) OVER (ORDER BY ORDER_YEAR_MONTH), 2) AS mom_growth_pct
FROM (
    SELECT ORDER_YEAR_MONTH, SUM(ORDER_VALUE) AS revenue
    FROM ORDERS
    WHERE IS_PARTIAL_PERIOD = 'N'
    GROUP BY ORDER_YEAR_MONTH
)
ORDER BY ORDER_YEAR_MONTH;

-- A5. Revenue by category
SELECT p.CATEGORY,
       COUNT(*)                     AS orders,
       ROUND(SUM(o.ORDER_VALUE),2)  AS revenue,
       ROUND(AVG(o.ORDER_VALUE),2)  AS avg_order_value
FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
GROUP BY p.CATEGORY
ORDER BY revenue DESC;

-- A6. Revenue by customer segment
SELECT c.CUSTOMER_SEGMENT,
       COUNT(*)                     AS orders,
       ROUND(SUM(o.ORDER_VALUE),2)  AS revenue,
       ROUND(AVG(o.ORDER_VALUE),2)  AS avg_order_value
FROM ORDERS o JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_SEGMENT
ORDER BY revenue DESC;

-- A7. Revenue by city
SELECT c.CITY,
       COUNT(*)                     AS orders,
       ROUND(SUM(o.ORDER_VALUE),2)  AS revenue
FROM ORDERS o JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CITY
ORDER BY revenue DESC;

-- A8. Revenue by payment method
SELECT PAYMENT_METHOD,
       COUNT(*)                     AS orders,
       ROUND(SUM(ORDER_VALUE),2)    AS revenue,
       ROUND(AVG(ORDER_VALUE),2)    AS avg_order_value
FROM ORDERS
GROUP BY PAYMENT_METHOD
ORDER BY revenue DESC;


-- =====================================================================
-- SECTION B: PRODUCT PERFORMANCE
-- =====================================================================

-- B1. Top 10 products by revenue
SELECT * FROM (
    SELECT p.PRODUCT_ID, p.SKU, p.CATEGORY, p.BRAND,
           SUM(o.QUANTITY)               AS units_sold,
           ROUND(SUM(o.ORDER_VALUE),2)   AS revenue,
           COUNT(*)                      AS orders
    FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
    GROUP BY p.PRODUCT_ID, p.SKU, p.CATEGORY, p.BRAND
    ORDER BY revenue DESC
) WHERE ROWNUM <= 10;

-- B2. Bottom 10 products by revenue (candidates for delisting review)
SELECT * FROM (
    SELECT p.PRODUCT_ID, p.SKU, p.CATEGORY, p.BRAND,
           SUM(o.QUANTITY)               AS units_sold,
           ROUND(SUM(o.ORDER_VALUE),2)   AS revenue,
           COUNT(*)                      AS orders
    FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
    GROUP BY p.PRODUCT_ID, p.SKU, p.CATEGORY, p.BRAND
    ORDER BY revenue ASC
) WHERE ROWNUM <= 10;

-- B3. Brand performance
SELECT BRAND,
       COUNT(*) AS orders,
       ROUND(SUM(ORDER_VALUE),2) AS revenue,
       ROUND(AVG(ORDER_VALUE),2) AS avg_order_value
FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
GROUP BY BRAND
ORDER BY revenue DESC;

-- B4. Return / cancellation rate by category
SELECT p.CATEGORY,
       ROUND(100 * SUM(CASE WHEN o.ORDER_STATUS='Returned' THEN 1 ELSE 0 END)/COUNT(*),2)  AS return_pct,
       ROUND(100 * SUM(CASE WHEN o.ORDER_STATUS='Cancelled' THEN 1 ELSE 0 END)/COUNT(*),2) AS cancel_pct
FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
GROUP BY p.CATEGORY
ORDER BY return_pct DESC;

-- B5. Average rating by product (delivered orders only - see data quality note)
SELECT p.PRODUCT_ID, p.SKU, p.CATEGORY,
       ROUND(AVG(o.RATING),2) AS avg_rating,
       COUNT(*)               AS rated_orders
FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
WHERE o.IS_DELIVERED_RATING = 'Y'
GROUP BY p.PRODUCT_ID, p.SKU, p.CATEGORY
HAVING COUNT(*) >= 20
ORDER BY avg_rating DESC
FETCH FIRST 10 ROWS ONLY;


-- =====================================================================
-- SECTION C: CUSTOMER ANALYSIS
-- =====================================================================

-- C1. Top 10 customers by lifetime revenue
SELECT * FROM (
    SELECT c.CUSTOMER_ID, c.CUSTOMER_NAME, c.CITY, c.CUSTOMER_SEGMENT,
           COUNT(*)                    AS orders,
           ROUND(SUM(o.ORDER_VALUE),2) AS lifetime_revenue
    FROM ORDERS o JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID
    GROUP BY c.CUSTOMER_ID, c.CUSTOMER_NAME, c.CITY, c.CUSTOMER_SEGMENT
    ORDER BY lifetime_revenue DESC
) WHERE ROWNUM <= 10;

-- C2. Orders-per-customer distribution (repeat purchase behavior)
SELECT order_count, COUNT(*) AS num_customers
FROM (
    SELECT CUSTOMER_ID, COUNT(*) AS order_count
    FROM ORDERS
    GROUP BY CUSTOMER_ID
)
GROUP BY order_count
ORDER BY order_count;

-- C3. One-time buyers vs repeat buyers
SELECT
    CASE WHEN order_count = 1 THEN 'One-time buyer' ELSE 'Repeat buyer' END AS buyer_type,
    COUNT(*)                                    AS customers,
    ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS pct
FROM (
    SELECT CUSTOMER_ID, COUNT(*) AS order_count
    FROM ORDERS
    GROUP BY CUSTOMER_ID
)
GROUP BY CASE WHEN order_count = 1 THEN 'One-time buyer' ELSE 'Repeat buyer' END;

-- C4. Customers registered but never ordered (Customers table LEFT JOIN Orders)
SELECT COUNT(*) AS never_ordered_customers
FROM CUSTOMERS c
LEFT JOIN ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
WHERE o.ORDER_ID IS NULL;

-- C5. RFM base query (Recency, Frequency, Monetary per customer)
-- Feeds the RFM segmentation done in Python/Excel; run this to refresh source numbers.
SELECT c.CUSTOMER_ID,
       (SELECT MAX(o2.ORDER_DATE) FROM ORDERS o2 WHERE o2.CUSTOMER_ID = c.CUSTOMER_ID) AS last_order_date,
       (SELECT TRUNC(MAX(o3.ORDER_DATE)) FROM ORDERS o3) + 1
         - (SELECT MAX(o4.ORDER_DATE) FROM ORDERS o4 WHERE o4.CUSTOMER_ID = c.CUSTOMER_ID) AS recency_days,
       COUNT(o.ORDER_ID)                AS frequency,
       ROUND(SUM(o.ORDER_VALUE),2)      AS monetary
FROM CUSTOMERS c
JOIN ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID;

-- C6. Revenue concentration - top 20% of customers vs. rest (Pareto check)
WITH cust_rev AS (
    SELECT CUSTOMER_ID, SUM(ORDER_VALUE) AS revenue,
           NTILE(5) OVER (ORDER BY SUM(ORDER_VALUE) DESC) AS quintile
    FROM ORDERS
    GROUP BY CUSTOMER_ID
)
SELECT quintile,
       COUNT(*)                    AS customers,
       ROUND(SUM(revenue),2)       AS revenue,
       ROUND(100*SUM(revenue)/SUM(SUM(revenue)) OVER (),2) AS pct_of_total_revenue
FROM cust_rev
GROUP BY quintile
ORDER BY quintile;


-- =====================================================================
-- SECTION D: DATA QUALITY / BUSINESS-RULE QUERIES
-- (used to justify the flags added during cleaning - see Data Quality Report)
-- =====================================================================

-- D1. Orders where recorded OrderValue diverges materially from Qty*UnitPrice
SELECT o.ORDER_ID, o.QUANTITY, p.UNIT_PRICE, o.ORDER_VALUE,
       o.COMPUTED_VALUE, o.VALUE_VARIANCE, o.VALUE_VARIANCE_PCT
FROM ORDERS o JOIN PRODUCTS p ON o.PRODUCT_ID = p.PRODUCT_ID
WHERE ABS(o.VALUE_VARIANCE_PCT) > 0.5
ORDER BY ABS(o.VALUE_VARIANCE_PCT) DESC
FETCH FIRST 20 ROWS ONLY;

-- D2. Ratings on non-delivered orders (should be treated with caution in reporting)
SELECT ORDER_STATUS, COUNT(*) AS orders_with_rating, ROUND(AVG(RATING),2) AS avg_rating
FROM ORDERS
WHERE ORDER_STATUS <> 'Delivered'
GROUP BY ORDER_STATUS;

-- D3. Statistical outliers in order value (flagged during cleaning)
SELECT COUNT(*) AS outlier_orders, ROUND(SUM(ORDER_VALUE),2) AS outlier_revenue
FROM ORDERS
WHERE IS_ORDERVALUE_OUTLIER = 'Y';
