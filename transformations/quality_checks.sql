-- 1. Check invalid daily returns.
SELECT COUNT(*) AS invalid_returns
FROM stock_daily_metrics
WHERE daily_return_pct <= -100;

-- 2. Check invalid moving averages.
SELECT COUNT(*) AS invalid_moving_averages
FROM stock_daily_metrics
WHERE moving_avg_7 <= 0
   OR moving_avg_30 <= 0;

-- 3. Check invalid volatility.
SELECT COUNT(*) AS invalid_volatility
FROM stock_daily_metrics
WHERE volatility_30d_pct < 0;

-- 4. Check volume anomaly distribution.
SELECT
    ticker,
    COUNT(*) FILTER (
        WHERE volume_anomaly = TRUE
    ) AS anomaly_days,
    COUNT(*) AS total_days
FROM stock_daily_metrics
GROUP BY ticker
ORDER BY ticker;

-- 5. Check first trading day for each stock.
SELECT ticker, date, previous_close, daily_return_pct
FROM stock_daily_metrics
WHERE row_num = 1
ORDER BY ticker;
