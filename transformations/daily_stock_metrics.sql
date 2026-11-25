-- MarketPulse: Day 3 Advanced SQL Analytics

BEGIN;

-- 1. Create the analytics table.
CREATE TABLE IF NOT EXISTS stock_daily_metrics (
    ticker VARCHAR(10) NOT NULL,
    date DATE NOT NULL,

    close NUMERIC(18, 6),
    previous_close NUMERIC(18, 6),
    next_close NUMERIC(18, 6),

    daily_return_pct NUMERIC(18, 6),

    moving_avg_7 NUMERIC(18, 6),
    moving_avg_30 NUMERIC(18, 6),

    volatility_30d_pct NUMERIC(18, 6),

    avg_volume_prev_30d NUMERIC(20, 2),
    volume_stddev_prev_30d NUMERIC(20, 2),
    volume_zscore NUMERIC(18, 6),
    volume_anomaly BOOLEAN,

    row_num BIGINT,
    highest_close_rank BIGINT,
    lowest_close_rank BIGINT,

    calculated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_stock_daily_metrics PRIMARY KEY (ticker, date)
);

-- 2. Refresh analytics from the source table.
TRUNCATE TABLE stock_daily_metrics;

-- 3. Calculate previous and next closing prices.
WITH price_history AS (
    SELECT
        ticker,
        date,
        close,
        volume,

        LAG(close) OVER (
            PARTITION BY ticker
            ORDER BY date
        ) AS previous_close,

        LEAD(close) OVER (
            PARTITION BY ticker
            ORDER BY date
        ) AS next_close,

        ROW_NUMBER() OVER (
            PARTITION BY ticker
            ORDER BY date
        ) AS row_num,

        RANK() OVER (
            PARTITION BY ticker
            ORDER BY close DESC
        ) AS highest_close_rank,

        RANK() OVER (
            PARTITION BY ticker
            ORDER BY close ASC
        ) AS lowest_close_rank

    FROM stock_prices
),

-- 4. Calculate daily returns and moving averages.
price_metrics AS (
    SELECT
        *,

        CASE
            WHEN previous_close IS NOT NULL
                 AND previous_close <> 0
            THEN
                ((close - previous_close) / previous_close) * 100
            ELSE NULL
        END AS daily_return_pct,

        AVG(close) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS moving_avg_7,

        AVG(close) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS moving_avg_30

    FROM price_history
),

-- 5. Calculate rolling volatility.
volatility_metrics AS (
    SELECT
        *,

        STDDEV_SAMP(daily_return_pct) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS volatility_30d_pct

    FROM price_metrics
),

-- 6. Calculate the previous 30 trading days' volume baseline.
volume_metrics AS (
    SELECT
        *,

        AVG(volume) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ) AS avg_volume_prev_30d,

        STDDEV_SAMP(volume) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ) AS volume_stddev_prev_30d

    FROM volatility_metrics
),

-- 7. Calculate volume anomaly score.
final_metrics AS (
    SELECT
        *,

        CASE
            WHEN volume_stddev_prev_30d > 0
            THEN
                (volume - avg_volume_prev_30d)
                / volume_stddev_prev_30d
            ELSE NULL
        END AS volume_zscore

    FROM volume_metrics
)

-- 8. Insert analytics into the permanent table.
INSERT INTO stock_daily_metrics (
    ticker,
    date,
    close,
    previous_close,
    next_close,
    daily_return_pct,
    moving_avg_7,
    moving_avg_30,
    volatility_30d_pct,
    avg_volume_prev_30d,
    volume_stddev_prev_30d,
    volume_zscore,
    volume_anomaly,
    row_num,
    highest_close_rank,
    lowest_close_rank
)
SELECT
    ticker,
    date,
    close,
    previous_close,
    next_close,
    daily_return_pct,
    moving_avg_7,
    moving_avg_30,
    volatility_30d_pct,
    avg_volume_prev_30d,
    volume_stddev_prev_30d,
    volume_zscore,

    CASE
        WHEN volume_zscore >= 3 THEN TRUE
        ELSE FALSE
    END AS volume_anomaly,

    row_num,
    highest_close_rank,
    lowest_close_rank

FROM final_metrics;

-- 9. Create indexes for analytics queries.
CREATE INDEX IF NOT EXISTS idx_metrics_date
ON stock_daily_metrics(date);

CREATE INDEX IF NOT EXISTS idx_metrics_ticker
ON stock_daily_metrics(ticker);

CREATE INDEX IF NOT EXISTS idx_metrics_anomaly
ON stock_daily_metrics(volume_anomaly);

COMMIT;
