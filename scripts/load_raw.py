"""
Charge les CSV bruts (data/raw/) dans PostgreSQL, schema `raw`.

Usage:
    python scripts/load_raw.py
"""
import os

import pandas as pd
from sqlalchemy import create_engine, text

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")

PG_URL = os.environ.get(
    "NBA_ANALYTICS_PG_URL",
    "postgresql+psycopg2://dbt_user:dbt_password@localhost:5544/nba_analytics",
)

TABLES = {
    "team_game_stats.csv": "team_game_stats",
    "team_advanced_stats.csv": "team_advanced_stats",
    "shots.csv": "shots",
}


def main() -> None:
    engine = create_engine(PG_URL)

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

    for csv_name, table_name in TABLES.items():
        csv_path = os.path.join(RAW_DIR, csv_name)
        if not os.path.exists(csv_path):
            raise FileNotFoundError(
                f"{csv_path} introuvable. Lance d'abord export_source_data.py et fetch_shots.py."
            )
        df = pd.read_csv(csv_path)
        df.columns = df.columns.str.lower()
        df.to_sql(
            table_name,
            engine,
            schema="raw",
            if_exists="replace",
            index=False,
        )
        print(f"raw.{table_name}: {len(df)} lignes chargees")


if __name__ == "__main__":
    main()
