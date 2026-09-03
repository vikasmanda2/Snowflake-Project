CREATE OR REPLACE WAREHOUSE ECOMMERCE_EVENT_WH
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

create or replace database ECOMMERCE_EVENT_DB;
create or replace schema LAKE_SCHEMA;
USE SCHEMA LAKE_SCHEMA;
--CREATE STAGING TABLE
CREATE OR REPLACE TABLE  STG_RAW_EVENT_PAYLOADS (
    RECORD_ID NUMBER AUTOINCREMENT,
    RAW_RECORD_TEXT VARCHAR
);
--LOADING  BATCH 1 DATA  WHICH IS IN JSON FORMAT
INSERT INTO STG_RAW_EVENT_PAYLOADS (RAW_RECORD_TEXT)
VALUES
('{"event_id":"EVT-8001","timestamp":"2026-07-01T08:15:00Z","user_id":1001,"page":"checkout","action":"purchase","order":{"total":12500.00,"shipping_cost":250.00,"tax":625.00,"items":2}}'),

('{"event_id":"EVT-8002","timestamp":"2026-07-01T08:20:00Z","user_id":1002,"page":"product_detail","action":"view","order":null}'),

('{"event_id":"EVT-8003","timestamp":"2026-07-01T08:35:00Z","user_id":1003,"page":"cart","action":"add_to_cart","order":null}'),

('{"event_id":"EVT-8004","timestamp":"2026-07-01T09:10:00Z","user_id":1004,"page":"checkout","action":"purchase","order":{"total":45000.00,"shipping_cost":500.00,"tax":2250.00,"items":5}}'),

('{"event_id":"EVT-8005","timestamp":"2026-07-01T09:45:00Z","user_id":1001,"page":"product_detail","action":"view","order":null}');

----LOADING  BATCH 2 DATA  WHICH IS IN JSON FORMAT
INSERT INTO STG_RAW_EVENT_PAYLOADS (RAW_RECORD_TEXT)
VALUES
('{"event_id":"EVT-8006","timestamp":"2026-07-02T10:00:00Z","user_id":1005,"page":"checkout","action":"purchase","order":{"total":18000.00,"shipping_cost":300.00,"tax":900.00,"items":3},"promo_code":"SUMMER20","discount_amount":3600.00}'),

('{"event_id":"EVT-8007","timestamp":"2026-07-02T10:15:00Z","user_id":1002,"page":"checkout","action":"purchase","order":{"total":8500.00,"shipping_cost":150.00,"tax":425.00,"items":1},"promo_code":"WELCOME10","discount_amount":850.00}'),

('{"event_id":"EVT-8008","timestamp":"2026-07-02T10:30:00Z","user_id":1006,"page":"cart","action":"add_to_cart","order":null,"promo_code":null,"discount_amount":0.00}'),

('{"event_id":"EVT-8009","timestamp":"2026-07-02T11:00:00Z","user_id":1003,"page":"checkout","action":"purchase","order":{"total":32000.00,"shipping_cost":400.00,"tax":1600.00,"items":4},"promo_code":"FESTIVE15","discount_amount":4800.00}'),

('{"event_id":"EVT-8010","timestamp":"2026-07-02T11:20:00Z","user_id":1007,"page":"product_detail","action":"view","order":null,"promo_code":null,"discount_amount":0.00}');

----LOADING  BATCH 3 DATA  WHICH IS IN JSON FORMAT
INSERT INTO STG_RAW_EVENT_PAYLOADS (RAW_RECORD_TEXT)
VALUES
('{"event_id":"EVT-8011","timestamp":"2026-07-03T12:00:00Z","user_id":1008,"page":"checkout","action":"purchase","order":{"total":0.00,"shipping_cost":0.00,"tax":0.00,"items":0},"promo_code":"FREEPASS","discount_amount":0.00}'),

('INVALID_JSON_PAYLOAD_MALFORMED_STRING');

SELECT COUNT(*) AS TOTAL_SOURCE_RECORDS
FROM STG_RAW_EVENT_PAYLOADS;

--TASK 1: DATA LAKE INGESTION
CREATE OR REPLACE TABLE LAKE_RAW_EVENTS (
    RAW_DATA VARIANT
);
--- LOAD VALD JSON FORMAT INTO THE DATA LAKE 
INSERT INTO LAKE_RAW_EVENTS (RAW_DATA)
SELECT TRY_PARSE_JSON(RAW_RECORD_TEXT)
FROM STG_RAW_EVENT_PAYLOADS
WHERE TRY_PARSE_JSON(RAW_RECORD_TEXT) IS NOT NULL;

SELECT COUNT(*) AS TOTAL_RAW_RECORD_CT
FROM LAKE_RAW_EVENTS;

--SCHEMA-ON-READ EXTRACTION
SELECT
    RAW_DATA:event_id::VARCHAR AS EVENT_ID,

    RAW_DATA:timestamp::TIMESTAMP_TZ AS EVENT_TIME,

    RAW_DATA:user_id::NUMBER AS USER_ID,

    RAW_DATA:action::VARCHAR AS ACTION,

    RAW_DATA:order.total::NUMBER(12,2) AS ORDER_TOTAL,

    RAW_DATA:promo_code::VARCHAR AS PROMO_CODE

FROM LAKE_RAW_EVENTS
ORDER BY EVENT_ID;

--NEATED JSON QUERY
SELECT
    RAW_DATA:event_id::VARCHAR AS EVENT_ID,
    RAW_DATA:order.total::NUMBER(12,2) AS ORDER_TOTAL,
    RAW_DATA:order.shipping_cost::NUMBER(12,2) AS SHIPPING_COST,
    RAW_DATA:order.tax::NUMBER(12,2) AS TAX,
    RAW_DATA:order.items::NUMBER AS ITEMS
FROM LAKE_RAW_EVENTS
ORDER BY EVENT_ID;

SELECT
    RAW_DATA:event_id::VARCHAR AS EVENT_ID,
    RAW_DATA:promo_code::VARCHAR AS PROMO_CODE,
    RAW_DATA:discount_amount::NUMBER(12,2) AS DISCOUNT_AMOUNT
FROM LAKE_RAW_EVENTS
ORDER BY EVENT_ID;

SELECT
    RAW_DATA:event_id::VARCHAR AS EVENT_ID,
    TO_CHAR(
        RAW_DATA:timestamp::TIMESTAMP_TZ,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS EVENT_TIME,
    RAW_DATA:user_id::NUMBER AS USER_ID,
    RAW_DATA:action::VARCHAR AS ACTION,
    RAW_DATA:order.total::NUMBER(12,2) AS ORDER_TOTAL,
    RAW_DATA:promo_code::VARCHAR AS PROMO_CODE
FROM LAKE_RAW_EVENTS
ORDER BY EVENT_ID;

--TASK 3: SCHEMA-ON-READ FINANCIAL ANALYSIS
SELECT
    RAW_DATA:event_id::VARCHAR AS EVENT_ID,

    RAW_DATA:order.total::NUMBER(12,2) AS ORDER_TOTAL,

    RAW_DATA:order.shipping_cost::NUMBER(12,2) AS SHIPPING_COST,

    RAW_DATA:order.tax::NUMBER(12,2) AS TAX,

    COALESCE(
        RAW_DATA:discount_amount::NUMBER(12,2),
        0
    ) AS DISCOUNT_AMOUNT,

    (
        RAW_DATA:order.total::NUMBER(12,2)
        - RAW_DATA:order.shipping_cost::NUMBER(12,2)
        - RAW_DATA:order.tax::NUMBER(12,2)
        - COALESCE(
            RAW_DATA:discount_amount::NUMBER(12,2),
            0
        )
    ) AS NET_REVENUE

FROM LAKE_RAW_EVENTS

WHERE RAW_DATA:action::VARCHAR = 'purchase'

AND RAW_DATA:order.total::NUMBER(12,2) > 0

ORDER BY EVENT_ID;

--Create a Reusable Extraction CTE
WITH EVENTS AS (
    SELECT
        RAW_DATA:event_id::VARCHAR AS EVENT_ID,
        RAW_DATA:action::VARCHAR AS ACTION,
        RAW_DATA:order.total::NUMBER(12,2) AS ORDER_TOTAL
    FROM LAKE_RAW_EVENTS
)

SELECT
    COUNT(*) AS TOTAL_EVENTS,

    COUNT_IF(
        ACTION = 'purchase'
        AND ORDER_TOTAL > 0
    ) AS TOTAL_PURCHASES,

    ROUND(
        COUNT_IF(
            ACTION = 'purchase'
            AND ORDER_TOTAL > 0
        ) * 100.0 / COUNT(*),
        2
    ) AS CONVERSION_RATE_PCT,

    SUM(
        CASE
            WHEN ACTION = 'purchase'
                 AND ORDER_TOTAL > 0
            THEN ORDER_TOTAL
            ELSE 0
        END
    ) AS TOTAL_GROSS_REVENUE,

    ROUND(
        SUM(
            CASE
                WHEN ACTION = 'purchase'
                     AND ORDER_TOTAL > 0
                THEN ORDER_TOTAL
                ELSE 0
            END
        )
        /
        NULLIF(
            COUNT_IF(
                ACTION = 'purchase'
                AND ORDER_TOTAL > 0
            ),
            0
        ),
        2
    ) AS AVERAGE_ORDER_VALUE

FROM EVENTS;

---Create DW_STRUCTURED_EVENTS
CREATE OR REPLACE TABLE DW_STRUCTURED_EVENTS (
    EVENT_ID VARCHAR,
    EVENT_TIME TIMESTAMP_TZ,
    USER_ID NUMBER,
    PAGE VARCHAR,
    ACTION VARCHAR,

    ORDER_TOTAL NUMBER(12,2),
    SHIPPING_COST NUMBER(12,2),
    TAX NUMBER(12,2),
    ITEMS NUMBER,

    PROMO_CODE VARCHAR,
    DISCOUNT_AMOUNT NUMBER(12,2),

    NET_REVENUE NUMBER(12,2)
);

---Backfill the Data Warehouse
INSERT INTO DW_STRUCTURED_EVENTS (
    EVENT_ID,
    EVENT_TIME,
    USER_ID,
    PAGE,
    ACTION,
    ORDER_TOTAL,
    SHIPPING_COST,
    TAX,
    ITEMS,
    PROMO_CODE,
    DISCOUNT_AMOUNT,
    NET_REVENUE
)
SELECT
    RAW_DATA:event_id::VARCHAR,

    RAW_DATA:timestamp::TIMESTAMP_TZ,

    RAW_DATA:user_id::NUMBER,

    RAW_DATA:page::VARCHAR,

    RAW_DATA:action::VARCHAR,

    COALESCE(
        RAW_DATA:order.total::NUMBER(12,2),
        0
    ),

    COALESCE(
        RAW_DATA:order.shipping_cost::NUMBER(12,2),
        0
    ),

    COALESCE(
        RAW_DATA:order.tax::NUMBER(12,2),
        0
    ),

    COALESCE(
        RAW_DATA:order.items::NUMBER,
        0
    ),

    RAW_DATA:promo_code::VARCHAR,

    COALESCE(
        RAW_DATA:discount_amount::NUMBER(12,2),
        0
    ),

    (
        COALESCE(
            RAW_DATA:order.total::NUMBER(12,2),
            0
        )
        -
        COALESCE(
            RAW_DATA:order.shipping_cost::NUMBER(12,2),
            0
        )
        -
        COALESCE(
            RAW_DATA:order.tax::NUMBER(12,2),
            0
        )
        -
        COALESCE(
            RAW_DATA:discount_amount::NUMBER(12,2),
            0
        )
    )

FROM LAKE_RAW_EVENTS;

--VALIDATE WAREHOUSE DATA WE ARE READ TO WRITE QUERY 
SELECT
    COUNT(*) AS STORED_RECORDS_QTY,
    SUM(NET_REVENUE) AS TOTAL_NET_REVENUE
FROM DW_STRUCTURED_EVENTS;

---Create Quarantine Table
CREATE OR REPLACE TABLE QUARANTINE_RAW_EVENTS (
    QUARANTINE_ID NUMBER AUTOINCREMENT,
    RAW_RECORD_TEXT VARCHAR,
    REASON VARCHAR
);
SELECT
    RECORD_ID,
    RAW_RECORD_TEXT
FROM STG_RAW_EVENT_PAYLOADS
WHERE TRY_PARSE_JSON(RAW_RECORD_TEXT) IS NULL;

INSERT INTO QUARANTINE_RAW_EVENTS (
    RAW_RECORD_TEXT,
    REASON
)
SELECT
    RAW_RECORD_TEXT,
    'MALFORMED_JSON_BODY'
FROM STG_RAW_EVENT_PAYLOADS
WHERE TRY_PARSE_JSON(RAW_RECORD_TEXT) IS NULL;

-- CREATING THE QUARANTINE IT IS FOR REPROCEES THE DATA TO STRORE IN IT

--- 
SELECT
    RECORD_ID,
    RAW_RECORD_TEXT
FROM STG_RAW_EVENT_PAYLOADS
WHERE TRY_PARSE_JSON(RAW_RECORD_TEXT) IS NULL;

--verify QUARANTINE
SELECT
    QUARANTINE_ID,
    RAW_RECORD_TEXT,
    REASON
FROM QUARANTINE_RAW_EVENTS
ORDER BY QUARANTINE_ID limit 1;