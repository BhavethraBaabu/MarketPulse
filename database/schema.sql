CREATE TABLE IF NOT EXISTS stock_prices (
    ticker VARCHAR(10) NOT NULL,
    date DATE NOT NULL,

    open NUMERIC(18, 6),
    high NUMERIC(18, 6),
    low NUMERIC(18, 6),
    close NUMERIC(18, 6),
    adj_close NUMERIC(18, 6),

    volume BIGINT,

    ingested_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_stock_prices
        PRIMARY KEY (ticker, date),

    CONSTRAINT chk_positive_prices CHECK (
        open > 0 AND
        high > 0 AND
        low > 0 AND
        close > 0
    ),

    CONSTRAINT chk_nonnegative_volume
        CHECK (volume >= 0),

    CONSTRAINT chk_valid_price_range CHECK (
        high >= low AND
        high >= open AND
        high >= close AND
        low <= open AND
        low <= close
    )
);

CREATE INDEX IF NOT EXISTS idx_stock_prices_date
ON stock_prices(date);

CREATE INDEX IF NOT EXISTS idx_stock_prices_ticker
ON stock_prices(ticker);
