import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parent.parent

load_dotenv(PROJECT_ROOT / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")


def main():

    if not DATABASE_URL:
        raise ValueError("DATABASE_URL missing from .env")

    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True
    )

    try:
        with engine.connect() as connection:

            # 1. Verify total analytics records.
            summary = connection.execute(text("""
                SELECT
                    COUNT(*) AS total_records,
                    COUNT(DISTINCT ticker) AS total_stocks,
                    MIN(date) AS earliest_date,
                    MAX(date) AS latest_date
                FROM stock_daily_metrics
            """)).fetchone()

            print("\n========== MARKETPULSE ANALYTICS ==========")
            print(f"Total records: {summary.total_records}")
            print(f"Total stocks: {summary.total_stocks}")
            print(f"Earliest date: {summary.earliest_date}")
            print(f"Latest date: {summary.latest_date}")

            # 2. Check for missing daily returns.
            missing_returns = connection.execute(text("""
                SELECT COUNT(*)
                FROM stock_daily_metrics
                WHERE daily_return_pct IS NULL
            """)).scalar_one()

            print(f"\nRecords without daily return: {missing_returns}")

            # 3. Show stock-level analytics.
            results = connection.execute(text("""
                SELECT
                    ticker,
                    COUNT(*) AS trading_days,
                    ROUND(AVG(daily_return_pct), 4)
                        AS avg_daily_return_pct,
                    ROUND(MAX(volatility_30d_pct), 4)
                        AS max_30d_volatility_pct,
                    COUNT(*) FILTER (
                        WHERE volume_anomaly = TRUE
                    ) AS volume_anomaly_days
                FROM stock_daily_metrics
                GROUP BY ticker
                ORDER BY ticker
            """)).fetchall()

            print("\n========== STOCK ANALYTICS SUMMARY ==========")

            for row in results:
                print(
                    f"{row.ticker}: "
                    f"Trading days={row.trading_days}, "
                    f"Average return={row.avg_daily_return_pct}%, "
                    f"Max rolling volatility={row.max_30d_volatility_pct}%, "
                    f"Volume anomalies={row.volume_anomaly_days}"
                )

            # 4. Verify duplicate ticker-date records.
            duplicates = connection.execute(text("""
                SELECT COUNT(*)
                FROM (
                    SELECT ticker, date
                    FROM stock_daily_metrics
                    GROUP BY ticker, date
                    HAVING COUNT(*) > 1
                ) AS duplicate_records
            """)).scalar_one()

            print(f"\nDuplicate ticker-date records: {duplicates}")

            # 5. Basic integrity checks.
            if summary.total_records == 0:
                raise RuntimeError("Analytics table is empty.")

            if duplicates > 0:
                raise RuntimeError("Duplicate ticker-date records found.")

            print("\nAnalytics verification successful.")

    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
