CREATE WAREHOUSE SALES_WH
WITH
WAREHOUSE_SIZE = 'X-SMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE;

SHOW WAREHOUSES;

CREATE DATABASE CUSTOMER_SALES_DB;

SHOW DATABASES;

CREATE SCHEMA CUSTOMER_SALES_DB.SALES_SCHEMA;

SHOW SCHEMAS IN DATABASE CUSTOMER_SALES_DB;

USE WAREHOUSE SALES_WH;

USE DATABASE CUSTOMER_SALES_DB;

USE SCHEMA SALES_SCHEMA;

SELECT CURRENT_WAREHOUSE(),
       CURRENT_DATABASE(),
       CURRENT_SCHEMA();

CREATE FILE FORMAT SALES_CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"';

SHOW FILE FORMATS;

CREATE STAGE SALES_STAGE
FILE_FORMAT = SALES_CSV_FORMAT;

SHOW STAGES;

LIST @SALES_STAGE;

CREATE TABLE CUSTOMERS (
    customer_id NUMBER,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(100)
);

CREATE TABLE FOODITEMS (
    food_id NUMBER,
    name VARCHAR(100),
    price NUMBER(10,2),
    category VARCHAR(50),
    availability VARCHAR(20)
);

CREATE TABLE ORDERS (
    order_id NUMBER,
    customer_id NUMBER,
    food_id NUMBER,
    quantity NUMBER,
    order_date TIMESTAMP,
    status VARCHAR(30),
    total_amount NUMBER(10,2)
);

SHOW TABLES;

COPY INTO CUSTOMERS
FROM @SALES_STAGE/customers.csv
FILE_FORMAT = SALES_CSV_FORMAT;

COPY INTO FOODITEMS
FROM @SALES_STAGE/fooditems.csv
FILE_FORMAT = SALES_CSV_FORMAT;

COPY INTO ORDERS
FROM @SALES_STAGE/orders.csv
FILE_FORMAT = SALES_CSV_FORMAT;

SELECT * FROM CUSTOMERS;
SELECT * FROM FOODITEMS;
SELECT * FROM ORDERS;

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_amount_spent
FROM CUSTOMERS c
JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY total_amount_spent DESC;

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_spent
FROM CUSTOMERS c
JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY total_spent DESC
LIMIT 1;

SELECT SUM(total_amount) AS total_revenue
FROM ORDERS;

SELECT
    f.category,
    SUM(o.total_amount) AS total_revenue
FROM FOODITEMS f
JOIN ORDERS o
    ON f.food_id = o.food_id
GROUP BY f.category
ORDER BY total_revenue DESC;

SELECT
    status AS order_status,
    SUM(total_amount) AS total_revenue
FROM ORDERS
GROUP BY status
ORDER BY total_revenue DESC;

SELECT
    ROW_NUMBER() OVER(ORDER BY SUM(o.total_amount) DESC) AS rank,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_spent
FROM CUSTOMERS c
JOIN ORDERS o
ON c.customer_id = o.customer_id
GROUP BY c.customer_id,c.first_name,c.last_name
ORDER BY total_spent DESC
LIMIT 3;

SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    COUNT(o.order_id) AS orders_placed
FROM CUSTOMERS c
JOIN ORDERS o
ON c.customer_id=o.customer_id
GROUP BY c.customer_id,c.first_name,c.last_name
ORDER BY c.customer_id;

SELECT *
FROM ORDERS
WHERE status='Delivered';

SELECT
    o.order_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    o.order_date,
    o.status,
    o.total_amount
FROM ORDERS o
JOIN CUSTOMERS c
ON o.customer_id=c.customer_id
WHERE o.order_date >= '2026-07-13'
ORDER BY o.order_date;

CREATE OR REPLACE VIEW CUSTOMER_SALES_REPORT AS
SELECT
    c.customer_id,
    CONCAT(c.first_name,' ',c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_amount_spent
FROM CUSTOMERS c
JOIN ORDERS o
ON c.customer_id=o.customer_id
GROUP BY c.customer_id,c.first_name,c.last_name;

SELECT * FROM CUSTOMER_SALES_REPORT;

SELECT *
FROM CUSTOMER_SALES_REPORT
ORDER BY total_amount_spent DESC;