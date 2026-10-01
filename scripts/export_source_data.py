"""
Exporte les tables SQLite du projet NBA-Game-Data vers des CSV bruts locaux
(data/raw/), qui serviront ensuite d'input a load_raw.py.

Usage:
    python scripts/export_source_data.py [--source-db PATH]
"""
import argparse
import os
import sqlite3

import pandas as pd

DEFAULT_SOURCE_DB = os.path.expanduser("~/NBA-Game-Data/export_data/nba_database.db")
RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")

TABLES = {
    "team_stats_history": "team_game_stats.csv",
    "team_advanced_history": "team_advanced_stats.csv",
}


def main(source_db: str) -> None:
    if not os.path.exists(source_db):
        raise FileNotFoundError(
            f"Base source introuvable: {source_db}. "
            "Passe --source-db si NBA-Game-Data n'est pas a cote de ce repo."
        )

    os.makedirs(RAW_DIR, exist_ok=True)
    conn = sqlite3.connect(source_db)

    for table_name, csv_name in TABLES.items():
        df = pd.read_sql(f"SELECT * FROM {table_name}", conn)
        out_path = os.path.join(RAW_DIR, csv_name)
        df.to_csv(out_path, index=False)
        print(f"{table_name}: {len(df)} lignes -> {out_path}")

    conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-db", default=DEFAULT_SOURCE_DB)
    args = parser.parse_args()
    main(args.source_db)
