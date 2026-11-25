-- 1. Latest daily metrics for every stock.
SELECT
    ticker,
    date,
    close,
    daily_return_pct,
    moving_avg_7,
    moving_avg_30,
    volatility_30d_pct
FROM stock_daily_metrics
ORDER BY date DESC, ticker
LIMIT 20;


-- 2. Highest closing price for each stock.
SELECT
    ticker,
    date,
    close AS highest_close
FROM stock_daily_metrics
WHERE highest_close_rank = 1
ORDER BY ticker;


-- 3. Lowest closing price for each stock.
SELECT
    ticker,
    date,
    close AS lowest_close
FROM stock_daily_metrics
WHERE lowest_close_rank = 1
ORDER BY ticker;


-- 4. Top 10 daily percentage gainers.
SELECT
    ticker,
    date,
    daily_return_pct
FROM stock_daily_metrics
WHERE daily_return_pct IS NOT NULL
ORDER BY daily_return_pct DESC
LIMIT 10;


-- 5. Top 10 daily percentage losers.
SELECT
    ticker,
    date,
    daily_return_pct
FROM stock_daily_metrics
WHERE daily_return_pct IS NOT NULL
ORDER BY daily_return_pct ASC
LIMIT 10;


-- 6. Highest-volume anomaly days.
SELECT
    ticker,
    date,
    volume_zscore,
    avg_volume_prev_30d
FROM stock_daily_metrics
WHERE volume_anomaly = TRUE
ORDER BY volume_zscore DESC
LIMIT 20;


-- 7. Most volatile stocks based on their latest available
-- 30-trading-day rolling volatility.
WITH latest_metrics AS (
    SELECT
        ticker,
        date,
        volatility_30d_pct,
        ROW_NUMBER() OVER (
            PARTITION BY ticker
            ORDER BY date DESC
        ) AS latest_row
    FROM stock_daily_metrics
)
SELECT
    ticker,
    date,
    volatility_30d_pct
FROM latest_metrics
WHERE latest_row = 1
ORDER BY volatility_30d_pct DESC;


-- 8. Compare latest closing price with moving averages.
WITH latest_prices AS (
    SELECT
        ticker,
        date,
        close,
        moving_avg_7,
        moving_avg_30,
        ROW_NUMBER() OVER (
            PARTITION BY ticker
            ORDER BY date DESC
        ) AS latest_row
    FROM stock_daily_metrics
)
SELECT
    ticker,
    date,
    close,
    moving_avg_7,
    moving_avg_30,
    CASE
        WHEN close > moving_avg_7
         AND close > moving_avg_30
        THEN 'Above both averages'
        WHEN close < moving_avg_7
         AND close < moving_avg_30
        THEN 'Below both averages'
        ELSE 'Mixed'
    END AS price_position
FROM latest_prices
WHERE latest_row = 1
ORDER BY ticker;


-- 9. Show previous and next closing prices using LAG and LEAD.
SELECT
    ticker,
    date,
    previous_close,
    close,
    next_close
FROM stock_daily_metrics
WHERE ticker = 'AAPL'
ORDER BY date DESC
LIMIT 15;


-- 10. Count trading records and anomalies per ticker.
SELECT
    ticker,
    COUNT(*) AS trading_days,
    COUNT(*) FILTER (
        WHERE volume_anomaly = TRUE
    ) AS high_volume_anomaly_days,
    ROUND(AVG(daily_return_pct), 4) AS average_daily_return_pct
FROM stock_daily_metrics
GROUP BY ticker
ORDER BY ticker;
