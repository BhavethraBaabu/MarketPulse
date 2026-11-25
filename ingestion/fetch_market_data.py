import yfinance as yf
import pandas as pd

from pathlib import Path
from datetime import datetime, timezone


# Configuration
TICKERS = ["AAPL", "MSFT", "NVDA", "AMZN", "GOOGL"]

START_DATE = "2024-01-01"
END_DATE = "2026-11-25"

OUTPUT_DIR = Path("data/raw")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def fetch_stock_data(ticker: str) -> pd.DataFrame:
    """Download historical daily stock prices."""

    print(f"\nDownloading {ticker}...")

    data = yf.download(
        ticker,
        start=START_DATE,
        end=END_DATE,
        interval="1d",
        auto_adjust=False,
        progress=False
    )

    if data.empty:
        raise ValueError(f"No data received for {ticker}")

    # Handle multi-level columns returned by yfinance
    if isinstance(data.columns, pd.MultiIndex):
        data.columns = data.columns.get_level_values(0)

    data = data.reset_index()

    data.columns = [
        str(column).lower().replace(" ", "_")
        for column in data.columns
    ]

    data["ticker"] = ticker
    data["ingested_at"] = datetime.now(timezone.utc)

    return data


def main():
    all_data = []
    failed_tickers = []

    for ticker in TICKERS:
        try:
            stock_data = fetch_stock_data(ticker)
            all_data.append(stock_data)

            print(
                f"{ticker}: "
                f"{len(stock_data)} records downloaded"
            )

        except Exception as error:
            failed_tickers.append(ticker)
            print(f"Failed {ticker}: {error}")

    if not all_data:
        raise RuntimeError("No stock data was downloaded.")

    combined_data = pd.concat(all_data, ignore_index=True)

    output_file = OUTPUT_DIR / "stock_prices.csv"

    combined_data.to_csv(output_file, index=False)

    print("\n========== INGESTION SUMMARY ==========")
    print(f"Successful stocks: {len(all_data)}")
    print(f"Failed stocks: {failed_tickers}")
    print(f"Total records: {len(combined_data)}")
    print(f"Saved to: {output_file}")


if __name__ == "__main__":
    main()
