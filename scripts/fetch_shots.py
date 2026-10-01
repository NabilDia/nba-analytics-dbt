"""
Recupere les tirs individuels (shot chart) de toutes les equipes NBA pour une
saison donnee, via l'endpoint ShotChartDetail de nba_api. Ecrit data/raw/shots.csv.

Reutilise le pattern de NBA-Game-Data/src/analyse.py::load_nba_player_shotchart,
en bouclant sur les 30 equipes (player_id=0 => tous les joueurs de l'equipe).

Usage:
    python scripts/fetch_shots.py [--season 2025-26]
"""
import argparse
import os
import time

import pandas as pd
from nba_api.stats.endpoints import ShotChartDetail
from nba_api.stats.static import teams

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")
OUT_PATH = os.path.join(RAW_DIR, "shots.csv")
DEFAULT_SEASON = "2025-26"


def fetch_team_shots(team_id: int, season: str) -> pd.DataFrame:
    response = ShotChartDetail(
        team_id=team_id,
        player_id=0,
        season_nullable=season,
        context_measure_simple="FGA",
        season_type_all_star="Regular Season",
        timeout=60,
    )
    return response.get_data_frames()[0]


def main(season: str) -> None:
    os.makedirs(RAW_DIR, exist_ok=True)
    all_teams = sorted(teams.get_teams(), key=lambda t: t["id"])

    frames = []
    for i, team in enumerate(all_teams, start=1):
        print(f"[{i}/{len(all_teams)}] {team['full_name']} ({team['id']}) - saison {season}")
        try:
            df = fetch_team_shots(team["id"], season)
        except Exception as exc:
            print(f"  echec pour {team['full_name']}: {exc}")
            continue
        print(f"  -> {len(df)} tirs")
        frames.append(df)
        time.sleep(0.6)  # limiter le rythme des appels a l'API NBA

    shots = pd.concat(frames, ignore_index=True)
    print(f"Total: {len(shots)} tirs sur {len(frames)} equipes")
    shots.to_csv(OUT_PATH, index=False)
    print(f"Ecrit dans {OUT_PATH}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--season", default=DEFAULT_SEASON)
    args = parser.parse_args()
    main(args.season)
