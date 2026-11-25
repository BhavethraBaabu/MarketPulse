import pandas as pd
from pathlib import Path

FILE_PATH = Path("data/raw/stock_prices.csv")


def main():

    if not FILE_PATH.exists():
        raise FileNotFoundError(
            "Stock dataset not found. Run fetch_market_data.py first."
        )

    df = pd.read_csv(FILE_PATH)

    print("\n========== DATA VALIDATION ==========")

    print("\n1. Dataset Shape:")
    print(df.shape)

    print("\n2. First 5 Records:")
    print(df.head())

    print("\n3. Column Information:")
    df.info()

    print("\n4. Missing Values:")
    print(df.isnull().sum())

    print("\n5. Duplicate Stock-Date Records:")
    print(
        df.duplicated(
            subset=["ticker", "date"]
        ).sum()
    )

    print("\n6. Stock Distribution:")
    print(df["ticker"].value_counts())

    print("\n7. Price Statistics:")
    print(
        df[
            ["open", "high", "low", "close", "volume"]
        ].describe()
    )

    print("\n8. Invalid Prices:")
    print((df["close"] <= 0).sum())

    print("\n========== VALIDATION COMPLETED ==========")


if __name__ == "__main__":
    main()
