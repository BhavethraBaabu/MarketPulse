import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text


# Project configuration
PROJECT_ROOT = Path(__file__).resolve().parent.parent

load_dotenv(PROJECT_ROOT / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")

CSV_PATH = PROJECT_ROOT / "data" / "raw" / "stock_prices.csv"


def read_stock_data():
    """Read and validate historical stock data."""

    if not CSV_PATH.exists():
        raise FileNotFoundError(f"CSV not found: {CSV_PATH}")

    print("Reading stock market CSV...")

    df = pd.read_csv(CSV_PATH)

    required_columns = [
        "ticker", "date", "open", "high",
        "low", "close", "adj_close",
        "volume", "ingested_at"
    ]

    missing = set(required_columns) - set(df.columns)

    if missing:
        raise ValueError(f"Missing columns: {missing}")

    df = df[required_columns].copy()

    df["date"] = pd.to_datetime(
        df["date"], errors="raise"
    ).dt.date

    df["ingested_at"] = pd.to_datetime(
        df["ingested_at"],
        utc=True,
        errors="raise"
    )

    if df.duplicated(["ticker", "date"]).any():
        raise ValueError("Duplicate ticker-date records found.")

    prices = ["open", "high", "low", "close"]

    if df[prices].isnull().any().any():
        raise ValueError("Missing price values found.")

    if (df[prices] <= 0).any().any():
        raise ValueError("Invalid prices found.")

    if df["volume"].isnull().any() or (df["volume"] < 0).any():
        raise ValueError("Invalid trading volumes found.")

    print(f"CSV records: {len(df)}")

    return df


def load_into_postgres(df, engine):
    """Load CSV records through a staging table."""

    staging_table = "stock_prices_staging"

    print("Loading records into staging table...")

    # Create and populate a regular staging table.
    df.to_sql(
        staging_table,
        engine,
        if_exists="replace",
        index=False,
        chunksize=1000,
        method="multi"
    )

    print("Staging table populated.")

    with engine.begin() as connection:

        # Insert records into the final table.
        # Update existing ticker-date records.
        connection.execute(text("""
            INSERT INTO stock_prices (
                ticker,
                date,
                open,
                high,
                low,
                close,
                adj_close,
                volume,
                ingested_at
            )
            SELECT
                ticker,
                date,
                open,
                high,
                low,
                close,
                adj_close,
                volume,
                ingested_at
            FROM stock_prices_staging

            ON CONFLICT (ticker, date)
            DO UPDATE SET
                open = EXCLUDED.open,
                high = EXCLUDED.high,
                low = EXCLUDED.low,
                close = EXCLUDED.close,
                adj_close = EXCLUDED.adj_close,
                volume = EXCLUDED.volume,
                ingested_at = EXCLUDED.ingested_at
        """))

        connection.execute(text(
            "DROP TABLE stock_prices_staging"
        ))

    print("Records successfully inserted.")


def verify_data(engine):
    """Verify records in the final table."""

    with engine.connect() as connection:

        result = connection.execute(text("""
            SELECT
                COUNT(*) AS total_records,
                COUNT(DISTINCT ticker) AS total_stocks,
                MIN(date) AS earliest_date,
                MAX(date) AS latest_date
            FROM stock_prices
        """)).fetchone()

        print("\n========== DATABASE SUMMARY ==========")
        print(f"Total records: {result[0]}")
        print(f"Total stocks: {result[1]}")
        print(f"Earliest date: {result[2]}")
        print(f"Latest date: {result[3]}")


def main():

    if not DATABASE_URL:
        raise ValueError("DATABASE_URL missing from .env")

    df = read_stock_data()

    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True
    )

    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))

        print("PostgreSQL connection successful.")

        load_into_postgres(df, engine)

        verify_data(engine)

        print("\nMarketPulse data ingestion completed.")

    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
