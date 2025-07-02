-- Extract duplicates rows if UNION ALL
WITH retail_u_all AS (
    SELECT * FROM retail_2009_2010
    UNION ALL 
    SELECT * FROM retail_2010_2011
)
SELECT invoice
    , stock_code
    , description
    , quantity
    , invoice_date
    , price
    , customer_id
    , country
    , COUNT(*) AS count
FROM retail_u_all
GROUP BY 
    invoice
    , stock_code
    , description
    , quantity
    , invoice_date
    , price
    , customer_id
    , country
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- Inspect origin of 20 duplicates
WITH retail_u_all AS (
    SELECT * FROM retail_2009_2010
    UNION ALL 
    SELECT * FROM retail_2010_2011
)
SELECT *
FROM retail_u_all
WHERE invoice = '555524'
  AND stock_code = '22698';
--=> Consider the wholesaler scenario, where they often buy in bulk, these are most likely mistakes of duplication.
--=> Remove duplicate, using UNION instead of UNION ALL

-- Union 2 tables
DROP VIEW IF EXISTS  retail_full;
CREATE VIEW retail_full AS
SELECT *, '2009_2010' AS year_labelled
    FROM retail_2009_2010

UNION

SELECT *, '2010_2011' AS year_labelled 
    FROM retail_2010_2011
;

----------------------------------------

-- Get an overview of the dataset
SELECT * FROM retail_full
LIMIT 10;


/** Invoice number. Nominal. A 6-digit integral number uniquely assigned to each transaction.
If this code starts with the letter 'c', it indicates a cancellation.  **/

-- Check invoice number
SELECT DISTINCT invoice
FROM retail_full
WHERE invoice !~ '^\d{6}$'        -- Those are not containing only 6 digits
;

-- Check starting letter rather than C
SELECT LEFT(invoice,1) start_letter, count(*) invoice_count
FROM retail_full
WHERE invoice !~ '^\d{6}$'
GROUP BY LEFT(invoice,1)
;

-- Inspecting Invoices rather than regular and cancelation invoices
SELECT *
FROM retail_full
WHERE starts_with(invoice, 'A')
;
-- => Invoices that start with A indicating bad debt => Keep data value

----------------------

-- Inspect cutomer_id for missing value.
SELECT *
FROM retail_full
WHERE customer_id IS NULL
LIMIT 10
;

/** I assume that if there is no value of customer ID then there was no transaction or invalid for analysis.
    => Therefore, filter out those rows with missing customer **/

-----------------------

-- Inspecting integer value of quantity column
SELECT
    min(quantity) min_quantity
    , ROUND(max(quantity),2) max_quantity
    , ROUND(avg(quantity),2) mean_quantity
    , ROUND(sum(quantity),2) total_quantity
    , PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY quantity) q1_quantity
    , PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY quantity) median_quantity
    , PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY quantity) q3_quantity
FROM retail_full
WHERE customer_id IS NOT NULL
;

-- Inspecting value of price column
SELECT
    min(price) min_price
    , ROUND(max(price),2) max_price
    , ROUND(avg(price),2) mean_price
    , ROUND(sum(price),2) total_price
    , PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price) q1_price
    , PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price) median_price
    , PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) q3_price
FROM retail_full
WHERE customer_id IS NOT NULL
;

/** Look into the huge difference in max, mean, median, quartile.
=> There are extremely large outliers which make the dataset unapproriate for customer behavioral analysis (find pattern).
=> Outliers can be seperated for another analysis to explore ocassional high expenses customer **/


-- Compute Z score and filter out extreme value which 2 times bigger than the stdev
--CREATE TABLE retail_clean AS        -- Create a cleaned table
WITH 
    stats AS (
        SELECT
            avg(quantity) mean_q
            , stddev(quantity) std_q
            , avg(price) mean_p
            , stddev(price) std_p
        FROM retail_full
        WHERE customer_id IS NOT NULL
    )
    , z_stats AS (
        SELECT 
            r.*
            , (r.quantity - stats.mean_q) / stats.std_q z_score_q
            , (r.price - stats.mean_p) / stats.std_p z_score_p
        FROM retail_full r, stats 
        WHERE customer_id IS NOT NULL
    )
SELECT 
    invoice
    , stock_code
    , quantity
    , TO_TIMESTAMP(invoice_date, 'DD/MM/YYYY HH24:MI')::DATE date -- Convert date_type & cast as date
    , price
    , customer_id
FROM z_stats
WHERE
    ABS(z_score_q) < 2              -- remove quantity outliers
    AND ABS(z_score_p) <2;           -- remove price outliers

------------------

-- Check for data type
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'retail_full'
  AND table_schema = 'public'
; 
-- => Invoice date data type is character var, need to changed into date type

-- Check date format & hour format for correction
SELECT 
    invoice_date
    ,LEFT(invoice_date, 10) date_
    ,RIGHT(invoice_date, 5) hour_
FROM retail_full
ORDER BY 2 DESC,3 DESC;
--=> current format is DD/MM/YYYY + HH24:MI


--------------------------------------------------

-- Create a cleaned table of data --
--=> Line 90

-- Check how much data did we drop through cleaning
WITH
    volumn_clean AS(
        SELECT COUNT(*) count_clean
        FROM retail_clean
    )
    , volumn_full AS(
        SELECT COUNT(*) count_raw
        FROM retail_full
    )
SELECT 
    count_clean
    ,count_raw
    ,100.0* count_clean/count_raw clean_percentage
    ,100 - 100.0* count_clean/count_raw dropped_percentage
FROM volumn_clean, volumn_full;
--=> The remaining clean data is ~76.78%, which we dropped ~23.21%


---------------------------------------------------



DROP TABLE IF EXISTS customers_rfm;
CREATE TABLE customers_rfm AS --Creating a table of customer recency, frequency, monetary value
WITH 
    compute_value AS(
        SELECT *
            , quantity * price invoice_value
        FROM retail_clean
        WHERE quantity > 0
        )
-- Becasue this is data in the past so would not be appropriate to use TODAY, but the most recent day in the dataset
    , today_replacement AS ( 
        SELECT MAX(date) most_recent_day
        FROM retail_clean
        )
SELECT 
    customer_id
    , SUM(invoice_value) customer_value
    , COUNT(DISTINCT invoice) frequency
    , ABS(MAX(date) - most_recent_day) recency
FROM compute_value, today_replacement
GROUP BY customer_id, most_recent_day
;
--=> There are Customers whose value is 0 or below. Worth to investigate

-- Inspect customer invoices which are negative
SELECT *
FROM retail_clean
WHERE (quantity < 1 OR price < 0) AND invoice !~ '^C';
--=> Monetary value is negative because of cancelled invoices
 
WITH 
    inspect_negativity AS(
        SELECT COUNT(*) negative_invoices_count
        FROM retail_clean
        WHERE (quantity < 1 OR price < 0) AND invoice ~ '^C'
    )
SELECT 
    negative_invoices_count 
    , COUNT(*)
    , ROUND(100.0* negative_invoices_count/COUNT(*),2)||'%' percent
FROM retail_clean, inspect_negativity
GROUP BY negative_invoices_count;
--=> It could be lack of historical transaction data, plus it only takes upto 2%. Therefore, drop the negative invoices




-------------------------

-- Check for actively runing queries behind the scence
SELECT pid, state, query
FROM pg_stat_activity
WHERE state != 'idle';
-- KILL running query
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
;


--------------------

-- Export customers_rfm and retail_clean table into csv file.
COPY customers_rfm TO '/Users/tieukbinh/Desktop/customers_rfm.csv' WITH CSV HEADER;

COPY retail_clean TO '/Users/tieukbinh/Desktop/retail_clean.csv' WITH CSV HEADER;