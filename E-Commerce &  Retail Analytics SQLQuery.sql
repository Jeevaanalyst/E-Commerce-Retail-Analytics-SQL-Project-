CREATE DATABASE RetailAnalytics;

USE RetailAnalytics;

DROP TABLE IF EXISTS retail_sales;
CREATE TABLE retail_sales (
    order_id                VARCHAR(15),
    order_line_id           VARCHAR(15),
    order_date              DATE,
    order_year              INT,
    order_month             INT,
    order_quarter           VARCHAR(5),
    order_day_of_week       VARCHAR(15),
    order_week_number       INT,
    customer_id             VARCHAR(12),
    customer_segment        VARCHAR(20),
    customer_age            INT,
    customer_gender         VARCHAR(10),
    loyalty_tier            VARCHAR(15),
    loyalty_points_earned   INT,
    loyalty_points_redeemed INT,
    city_tier               VARCHAR(10),
    state                  VARCHAR(30),
    channel                 VARCHAR(25),
    store_id                VARCHAR(10),
    warehouse_id            VARCHAR(10),
    product_id              VARCHAR(10),
    category                VARCHAR(25),
    subcategory             VARCHAR(30),
    brand_tier              VARCHAR(20),
    unit_price              DECIMAL(12,2),
    quantity                INT,
    discount_event          VARCHAR(25),
    discount_pct            DECIMAL(6,4),
    discount_amt            DECIMAL(12,2),
    selling_price           DECIMAL(12,2),
    gross_revenue           DECIMAL(12,2),
    cogs                    DECIMAL(12,2),
    gross_profit            DECIMAL(12,2),
    gross_margin_pct        DECIMAL(6,4),
    shipping_mode           VARCHAR(20),
    shipping_cost           DECIMAL(10,2),
    dispatch_days           INT,
    delivery_days           INT,
    return_flag             INT,
    return_reason           VARCHAR(30),
    return_value            DECIMAL(12,2),
    net_revenue             DECIMAL(12,2),
    payment_method          VARCHAR(20),
    payment_status          VARCHAR(15),
    rating                  INT,
    nps_score               INT
);


-- BULK INSERT (update file path to where you saved the CSV)
BULK INSERT retail_sales
FROM 'C:\Users\Jeeva D\OneDrive\Desktop\Retail Analytics Data\retail_sales.csv'
WITH (
    FORMAT        = 'CSV',
    FIRSTROW      = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    TABLOCK
);

-- Verify load
SELECT COUNT(*) AS total_rows FROM retail_sales;

-- DATA QUALITY CHECKS
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT order_id)        AS unique_orders,
    COUNT(DISTINCT customer_id)     AS unique_customers,
    COUNT(DISTINCT product_id)      AS unique_products,
    MIN(order_date)                 AS earliest_date,
    MAX(order_date)                 AS latest_date,
    SUM(CASE WHEN gross_revenue < 0  THEN 1 ELSE 0 END) AS negative_revenue,
    SUM(CASE WHEN quantity <= 0      THEN 1 ELSE 0 END) AS zero_qty_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customers
FROM retail_sales;

-- NULL check across all key columns
SELECT
    SUM(CASE WHEN order_date       IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN customer_id      IS NULL THEN 1 ELSE 0 END) AS null_customer,
    SUM(CASE WHEN gross_revenue    IS NULL THEN 1 ELSE 0 END) AS null_revenue,
    SUM(CASE WHEN category         IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN payment_status   IS NULL THEN 1 ELSE 0 END) AS null_payment,
    SUM(CASE WHEN return_flag      IS NULL THEN 1 ELSE 0 END) AS null_return
FROM retail_sales;

-- Duplicate order line check
SELECT order_line_id, COUNT(*) AS cnt
FROM retail_sales
GROUP BY order_line_id
HAVING COUNT(*) > 1;




-- Overall business KPIs
SELECT
    FORMAT(COUNT(order_id),'N0')                                 AS total_orders,
    FORMAT(COUNT(DISTINCT customer_id),'N0')                     AS unique_customers,
    FORMAT(SUM(gross_revenue)/1e7,'N2') + ' Cr'                  AS gross_revenue_cr,
    FORMAT(SUM(net_revenue)/1e7,'N2')   + ' Cr'                  AS net_revenue_cr,
    FORMAT(SUM(gross_profit)/1e7,'N2')  + ' Cr'                  AS gross_profit_cr,
    FORMAT(AVG(gross_margin_pct)*100,'N1') + '%'                 AS avg_gross_margin,
    FORMAT(AVG(gross_revenue),'N0')                              AS avg_order_value,
    FORMAT(SUM(return_value)/SUM(gross_revenue)*100,'N1') + '%'  AS return_rate,
    FORMAT(SUM(discount_amt)/SUM(gross_revenue+discount_amt)*100,'N1') + '%' AS avg_discount_depth,
    FORMAT(AVG(CAST(rating AS FLOAT)),'N2')                      AS avg_rating,
    FORMAT(AVG(CAST(delivery_days AS FLOAT)),'N1') + ' days'     AS avg_delivery_days
FROM retail_sales
WHERE payment_status = 'Paid';

-- Revenue waterfall from gross to net
SELECT
    ROUND(SUM(gross_revenue + discount_amt),0)  AS mrp_revenue,
    ROUND(SUM(discount_amt),0)                  AS total_discounts,
    ROUND(SUM(gross_revenue),0)                 AS gross_revenue,
    ROUND(SUM(return_value),0)                  AS total_returns,
    ROUND(SUM(net_revenue),0)                   AS net_revenue,
    ROUND(SUM(cogs),0)                          AS total_cogs,
    ROUND(SUM(shipping_cost),0)                 AS total_shipping_cost,
    ROUND(SUM(gross_profit) - SUM(shipping_cost),0) AS contribution_margin
FROM retail_sales;



-- SALES TREND ANALYSIS ( Monthly revenue trend with MoM growth )
WITH monthly_rev AS (
    SELECT
        order_year,
        order_month,
        DATEFROMPARTS(order_year,order_month,1)     AS month_date,
        SUM(net_revenue)                            AS net_revenue,
        COUNT(DISTINCT order_id)                    AS orders,
        COUNT(DISTINCT customer_id)                 AS customers,
        AVG(gross_revenue)                          AS avg_order_value
    FROM retail_sales
    GROUP BY order_year, order_month
)
SELECT
    order_year,
    order_month,
    ROUND(net_revenue,0)                            AS net_revenue,
    orders,
    customers,
    ROUND(avg_order_value,0)                        AS avg_order_value,
    ROUND(LAG(net_revenue) OVER (ORDER BY month_date),0)
                                                    AS prev_month_revenue,
    ROUND((net_revenue - LAG(net_revenue) OVER (ORDER BY month_date))
          / NULLIF(LAG(net_revenue) OVER (ORDER BY month_date),0)*100, 2)
                                                    AS mom_growth_pct,
    ROUND(LAG(net_revenue,12) OVER (ORDER BY month_date),0)
                                                    AS same_month_last_year,
    ROUND((net_revenue - LAG(net_revenue,12) OVER (ORDER BY month_date))
          / NULLIF(LAG(net_revenue,12) OVER (ORDER BY month_date),0)*100, 2)
                                                    AS yoy_growth_pct
FROM monthly_rev
ORDER BY month_date;

-- Quarterly performance with running total
SELECT
    order_year,
    order_quarter,
    ROUND(SUM(net_revenue),0)                       AS quarterly_revenue,
    ROUND(SUM(gross_profit),0)                      AS quarterly_profit,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    COUNT(DISTINCT order_id)                        AS total_orders,
    ROUND(SUM(SUM(net_revenue)) OVER (
        PARTITION BY order_year
        ORDER BY order_quarter
        ROWS UNBOUNDED PRECEDING
    ),0)                                            AS ytd_revenue,
    ROUND(SUM(net_revenue)*100.0 / SUM(SUM(net_revenue)) OVER (
        PARTITION BY order_year),2)                 AS pct_of_year_revenue
FROM retail_sales
GROUP BY order_year, order_quarter
ORDER BY order_year, order_quarter;

-- Day-of-week sales pattern
SELECT
    order_day_of_week,
    DATEPART(WEEKDAY, order_date)                   AS day_number,
    COUNT(order_id)                                 AS total_orders,
    ROUND(SUM(net_revenue),0)                       AS total_revenue,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(AVG(CAST(rating AS FLOAT)),2)             AS avg_rating
FROM retail_sales
GROUP BY order_day_of_week, DATEPART(WEEKDAY, order_date)
ORDER BY day_number;

--  Seasonal sale event impact
SELECT
    discount_event,
    COUNT(order_id)                                 AS total_orders,
    ROUND(SUM(gross_revenue),0)                     AS gross_revenue,
    ROUND(SUM(discount_amt),0)                      AS total_discount_given,
    ROUND(AVG(discount_pct)*100,2)                  AS avg_discount_pct,
    ROUND(SUM(gross_profit),0)                      AS gross_profit,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    ROUND(SUM(return_value)/NULLIF(SUM(gross_revenue),0)*100,2) AS return_rate_pct
FROM retail_sales
GROUP BY discount_event
ORDER BY gross_revenue DESC;

-- PRODUCT & CATEGORY ANALYSIS
-- Category P&L summary
SELECT
    category,
    COUNT(order_id)                                 AS orders,
    SUM(quantity)                                   AS units_sold,
    ROUND(SUM(gross_revenue)/1e6,2)                 AS revenue_mn,
    ROUND(SUM(gross_profit)/1e6,2)                  AS profit_mn,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    ROUND(SUM(discount_amt)/1e6,2)                  AS discount_mn,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(AVG(CAST(rating AS FLOAT)),2)             AS avg_rating,
    RANK() OVER (ORDER BY SUM(gross_revenue) DESC)  AS revenue_rank,
    RANK() OVER (ORDER BY AVG(gross_margin_pct) DESC) AS margin_rank
FROM retail_sales
GROUP BY category
ORDER BY revenue_rank;

--  Subcategory with  category share
SELECT
    category,
    subcategory,
    COUNT(order_id)                                 AS orders,
    ROUND(SUM(gross_revenue),0)                     AS revenue,
    ROUND(SUM(gross_revenue)*100.0 / SUM(SUM(gross_revenue)) OVER (
        PARTITION BY category),2)                   AS pct_of_category,
    ROUND(SUM(gross_revenue)*100.0 / SUM(SUM(gross_revenue)) OVER (),2)
                                                    AS pct_of_total,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct
FROM retail_sales
GROUP BY category, subcategory
ORDER BY category, revenue DESC;

-- Price  discount vs volume
SELECT
    category,
    CASE
        WHEN discount_pct = 0             THEN '0% (No Discount)'
        WHEN discount_pct <= 0.10         THEN '1-10%'
        WHEN discount_pct <= 0.20         THEN '11-20%'
        WHEN discount_pct <= 0.30         THEN '21-30%'
        WHEN discount_pct <= 0.50         THEN '31-50%'
        ELSE '50%+'
    END                                             AS discount_band,
    COUNT(order_id)                                 AS orders,
    SUM(quantity)                                   AS units_sold,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct
FROM retail_sales
GROUP BY category,
    CASE
        WHEN discount_pct = 0             THEN '0% (No Discount)'
        WHEN discount_pct <= 0.10         THEN '1-10%'
        WHEN discount_pct <= 0.20         THEN '11-20%'
        WHEN discount_pct <= 0.30         THEN '21-30%'
        WHEN discount_pct <= 0.50         THEN '31-50%'
        ELSE '50%+'
    END
ORDER BY category, discount_band;



-- Top 20 products by revenue
SELECT TOP 20
    product_id,
    category,
    subcategory,
    brand_tier,
    COUNT(order_id)                                 AS orders,
    SUM(quantity)                                   AS units_sold,
    ROUND(AVG(unit_price),2)                        AS avg_unit_price,
    ROUND(SUM(gross_revenue),0)                     AS total_revenue,
    ROUND(SUM(gross_profit),0)                      AS total_profit,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    ROUND(AVG(CAST(rating AS FLOAT)),2)             AS avg_rating,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct
FROM retail_sales
GROUP BY product_id, category, subcategory, brand_tier
ORDER BY total_revenue DESC;



-- CUSTOMER ANALYTICS

--  Customer segment performance
SELECT
    customer_segment,
    COUNT(DISTINCT customer_id)                     AS unique_customers,
    COUNT(order_id)                                 AS total_orders,
    ROUND(COUNT(order_id)*1.0/COUNT(DISTINCT customer_id),1) AS orders_per_customer,
    ROUND(SUM(net_revenue),0)                       AS total_revenue,
    ROUND(SUM(net_revenue)/COUNT(DISTINCT customer_id),0) AS revenue_per_customer,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(SUM(loyalty_points_earned),0)             AS total_points_earned,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct,
    ROUND(AVG(CAST(nps_score AS FLOAT)),1)          AS avg_nps
FROM retail_sales
GROUP BY customer_segment
ORDER BY revenue_per_customer DESC;

--  Customer Lifetime Value (CLV) 
WITH customer_orders AS (
    SELECT
        customer_id,
        customer_segment,
        loyalty_tier,
        COUNT(DISTINCT order_id)                        AS total_orders,
        ROUND(SUM(net_revenue),0)                       AS total_spent,
        MIN(order_date)                                 AS first_purchase,
        MAX(order_date)                                 AS last_purchase,
        DATEDIFF(DAY,MIN(order_date),MAX(order_date))   AS customer_lifespan_days
    FROM retail_sales
    WHERE payment_status = 'Paid'
    GROUP BY customer_id, customer_segment, loyalty_tier
)
SELECT
    customer_segment,
    loyalty_tier,
    COUNT(customer_id)                                  AS customers,
    ROUND(AVG(total_orders),1)                          AS avg_orders,
    ROUND(AVG(total_spent),0)                           AS avg_clv,
    ROUND(MAX(total_spent),0)                           AS max_clv,
    ROUND(AVG(total_spent/NULLIF(total_orders,0)),0)    AS avg_order_value,
    ROUND(AVG(customer_lifespan_days),0)                AS avg_lifespan_days,
    ROUND(AVG(total_spent/NULLIF(customer_lifespan_days/30.0,0)),0)
                                                        AS avg_monthly_value
FROM customer_orders
GROUP BY customer_segment, loyalty_tier
ORDER BY avg_clv DESC;

 -- CHANNEL & GEOGRAPHIC ANALYSIS
-- channel performance comparison
SELECT
    channel,
    COUNT(DISTINCT customer_id)                     AS unique_customers,
    COUNT(order_id)                                 AS total_orders,
    ROUND(SUM(gross_revenue)/1e6,2)                 AS revenue_mn,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(AVG(gross_margin_pct)*100,2)              AS avg_margin_pct,
    ROUND(SUM(discount_amt)/SUM(gross_revenue+discount_amt)*100,2) AS discount_rate_pct,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct,
    ROUND(AVG(CAST(delivery_days AS FLOAT)),1)      AS avg_delivery_days,
    ROUND(AVG(CAST(rating AS FLOAT)),2)             AS avg_rating,
    ROUND(SUM(gross_revenue)*100.0/SUM(SUM(gross_revenue)) OVER(),2)
                                                    AS channel_revenue_share_pct
FROM retail_sales
GROUP BY channel
ORDER BY revenue_mn DESC;

-- State-level revenue and growth
WITH state_rev AS (
    SELECT
        state,
        order_year,
        SUM(net_revenue)                            AS revenue
    FROM retail_sales
    GROUP BY state, order_year
)
SELECT
    state,
    ROUND(SUM(CASE WHEN order_year=2022 THEN revenue ELSE 0 END),0) AS rev_2022,
    ROUND(SUM(CASE WHEN order_year=2023 THEN revenue ELSE 0 END),0) AS rev_2023,
    ROUND(SUM(CASE WHEN order_year=2024 THEN revenue ELSE 0 END),0) AS rev_2024,
    ROUND((SUM(CASE WHEN order_year=2024 THEN revenue ELSE 0 END)
         - SUM(CASE WHEN order_year=2023 THEN revenue ELSE 0 END))
         / NULLIF(SUM(CASE WHEN order_year=2023 THEN revenue ELSE 0 END),0)*100,2)
                                                    AS yoy_growth_pct_2024,
    RANK() OVER (ORDER BY SUM(CASE WHEN order_year=2024 THEN revenue ELSE 0 END) DESC)
                                                    AS rev_rank_2024
FROM state_rev
GROUP BY state
ORDER BY rev_rank_2024;

--City tier revenue
SELECT
    city_tier,
    channel,
    COUNT(order_id)                                 AS orders,
    ROUND(SUM(gross_revenue)/1e6,2)                 AS revenue_mn,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct
FROM retail_sales
GROUP BY city_tier, channel
ORDER BY city_tier, revenue_mn DESC;

 -- RETURN RATE & QUALITY ANALYSIS
-- Return rate by category and channel
SELECT
    category,
    channel,
    COUNT(order_id)                                 AS total_orders,
    SUM(return_flag)                                AS returned_orders,
    ROUND(SUM(return_flag)*100.0/COUNT(order_id),2) AS return_rate_pct,
    ROUND(SUM(return_value),0)                      AS total_return_value,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_value_pct
FROM retail_sales
GROUP BY category, channel
ORDER BY return_rate_pct DESC;


-- Return reason with financial impact
SELECT
    return_reason,
    COUNT(order_id)                                 AS return_count,
    ROUND(SUM(return_value),0)                      AS total_return_value,
    ROUND(AVG(return_value),0)                      AS avg_return_value,
    ROUND(SUM(return_value)*100.0/SUM(SUM(return_value)) OVER(),2)
                                                    AS pct_of_total_returns,
    ROUND(AVG(CAST(rating AS FLOAT)),2)             AS avg_rating,
    (SELECT TOP 1 category FROM retail_sales r2
     WHERE r2.return_reason = r1.return_reason
     GROUP BY category ORDER BY COUNT(*) DESC)     AS top_category
FROM retail_sales r1
WHERE return_flag = 1
GROUP BY return_reason
ORDER BY total_return_value DESC;

-- PAYMENT & LOYALTY ANALYTICS
-- Payment method breakdown
SELECT
    payment_method,
    payment_status,
    COUNT(order_id)                                 AS orders,
    ROUND(SUM(gross_revenue),0)                     AS revenue,
    ROUND(AVG(gross_revenue),0)                     AS avg_order_value,
    ROUND(SUM(return_value)/SUM(gross_revenue)*100,2) AS return_rate_pct
FROM retail_sales
GROUP BY payment_method, payment_status
ORDER BY payment_method, orders DESC;

 -- Market basket which categories are bought together
SELECT
    a.category                                      AS category_1,
    b.category                                      AS category_2,
    COUNT(*)                                        AS co_occurrence,
    ROUND(COUNT(*)*100.0 / (
        SELECT COUNT(DISTINCT customer_id) FROM retail_sales
    ),4)                                            AS support_pct
FROM retail_sales a
JOIN retail_sales b
    ON  a.customer_id = b.customer_id
    AND a.category    < b.category
    AND a.order_id   <> b.order_id
GROUP BY a.category, b.category
ORDER BY co_occurrence DESC;

 -- PIVOT Revenue by channel across years
SELECT *
FROM (
    SELECT channel, order_year,
           ROUND(SUM(gross_revenue)/1e6,2) AS revenue_mn
    FROM retail_sales
    GROUP BY channel, order_year
) src
PIVOT (
    SUM(revenue_mn)
    FOR order_year IN ([2020],[2021],[2022],[2023],[2024])
) pvt
ORDER BY [2024] DESC;

-- Running total and market share by category per month
SELECT
    order_year,
    order_month,
    category,
    ROUND(SUM(gross_revenue),0)                     AS monthly_revenue,
    ROUND(SUM(gross_revenue)*100.0/SUM(SUM(gross_revenue)) OVER (
        PARTITION BY order_year, order_month),2)    AS market_share_pct,
    ROUND(SUM(SUM(gross_revenue)) OVER (
        PARTITION BY order_year, category
        ORDER BY order_month
        ROWS UNBOUNDED PRECEDING),0)                AS ytd_revenue
FROM retail_sales
GROUP BY order_year, order_month, category
ORDER BY order_year, order_month, monthly_revenue DESC;



-- Top N products per category (ranking per group)
WITH ranked_products AS (
    SELECT
        category,
        product_id,
        subcategory,
        ROUND(SUM(gross_revenue),0)                 AS revenue,
        COUNT(order_id)                             AS orders,
        ROUND(AVG(gross_margin_pct)*100,2)          AS margin_pct,
        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY SUM(gross_revenue) DESC
        )                                           AS rank_in_category
    FROM retail_sales
    GROUP BY category, product_id, subcategory
)
SELECT * FROM ranked_products
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;
