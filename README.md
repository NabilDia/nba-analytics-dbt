# NBA Analytics — Pipeline de transformation dbt

Projet **dbt Core** sur PostgreSQL : transformation de données NBA brutes en un modèle analytique
en schéma en étoile, avec tests de qualité, documentation et lineage générés.

---

## Contexte

Les données brutes (statistiques de matchs et d'équipes sur la saison 2025-26, ~2 460 lignes
match×équipe, et ~219 000 tirs individuels sur la même saison) sont ingérées dans un schéma
`raw` PostgreSQL, puis transformées par dbt en modèles analytiques exploitables : indicateurs
de performance par équipe et analyse d'efficacité au tir par zone.

Les statistiques de matchs/équipes réutilisent les données déjà collectées par le projet
[NBA-Game-Data](https://github.com/NabilDia) (via `nba_api`, stockées en SQLite). Les tirs
individuels (coordonnées x/y, zone, réussite) n'existaient dans aucune donnée existante : ils
ont été récupérés spécifiquement pour ce projet via l'endpoint `ShotChartDetail` de `nba_api`
(voir `scripts/fetch_shots.py`), sur les 30 équipes de la saison 2025-26.

**Objectif technique** : mettre en place une chaîne de transformation testée, documentée et
traçable, plutôt qu'une suite de requêtes SQL isolées.

---

## Stack

| Composant | Choix |
|---|---|
| Transformation | dbt Core 1.8.8 (adapter dbt-postgres 1.8.2) |
| Entrepôt | PostgreSQL 16 (Docker) |
| Ingestion | Python / pandas (`to_sql` vers le schéma `raw`) + `nba_api` (ShotChartDetail) |
| Versioning | Git / GitHub |

---

## Architecture

```
models/
├── staging/              # 1 modèle par source : nettoyage, renommage, typage
│   ├── _sources.yml      # déclaration des sources + freshness
│   ├── stg_games.sql
│   ├── stg_teams.sql
│   └── stg_shots.sql
└── marts/                # modèle analytique en schéma en étoile
    ├── _models.yml       # tests + descriptions
    ├── dim_team.sql
    ├── fct_game.sql
    └── fct_shot_efficiency.sql
seeds/
└── team_reference.csv    # mapping statique team_id -> conference/division (30 lignes)
snapshots/
└── snap_team.sql          # historisation SCD type 2
tests/
└── assert_shooting_pct_valide.sql   # test singulier métier
```

**Convention** : les modèles `staging` lisent les sources via `source()`, les modèles `marts`
lisent exclusivement via `ref()`. C'est cette discipline qui rend le lineage exploitable.

**Décisions de modélisation** :

- `fct_game` est au grain **équipe × match** (une ligne par équipe par match), pas une ligne
  par match avec home/away. C'est le grain natif de la source (`TeamGameLogs` de `nba_api`) et
  il simplifie les clés étrangères vers `dim_team` (pas de `home_team_id`/`away_team_id`
  dupliqué à gérer).
- `stg_teams` ne garde que le **profil de performance le plus récent par équipe** (la dernière
  saison disponible par `team_id`), même si la source (`team_advanced_stats`) est au grain
  équipe × saison. C'est ce modèle qui alimente `dim_team` et `snap_team` : l'historique
  multi-saison, lui, est déjà porté par `fct_game`.

### Lineage

Le lineage complet (staging -> marts, avec les sources et le seed) est généré par
`dbt docs generate` et consultable via `dbt docs serve` (voir Installation ci-dessous). Je n'ai
pas inclus de capture d'écran statique ici : l'interface est interactive et se régénère à
chaque run, autant la consulter en direct plutôt qu'à partir d'une image qui devient obsolète
au premier changement de modèle.

---

## Qualité des données

La qualité est testée à chaque exécution, pas vérifiée à la main. `dbt build` exécute
**15 tests** (14 génériques + 1 singulier), tous verts.

**Tests génériques** (déclarés dans `_models.yml` / `_seeds.yml`) :

| Test | Appliqué à | Ce qu'il garantit |
|---|---|---|
| `unique` | `dim_team.team_id`, `team_reference.team_id` | Pas de doublon de clé |
| `not_null` | `dim_team.team_id`, `fct_game.game_id`/`team_id`, `fct_shot_efficiency.team_id`/`shot_zone_basic` | Complétude des identifiants |
| `relationships` | `fct_game.team_id` → `dim_team.team_id`, `fct_shot_efficiency.team_id` → `dim_team.team_id` | Intégrité référentielle |
| `accepted_values` | `dim_team.conference` ∈ [East, West], `fct_game.is_win` ∈ [true, false] | Domaine de valeurs respecté |
| `dbt_utils.unique_combination_of_columns` | `fct_game` (game_id, team_id) | Pas de doublon sur la clé composite du fait |

**Test singulier métier** — `tests/assert_shooting_pct_valide.sql` : vérifie qu'aucun
pourcentage d'adresse au tir (`fct_shot_efficiency.fg_pct`) ne sort de l'intervalle [0, 1]. Une
incohérence de calcul en amont (ex. tirs réussis > tirs tentés) fait échouer le build plutôt que
de se propager dans les analyses.

---

## Scalabilité

Le modèle `fct_game` est matérialisé en **incrémental** : seules les lignes postérieures à la
dernière date chargée sont traitées à chaque exécution, au lieu d'une reconstruction complète
de la table.

```sql
{{ config(materialized='incremental', unique_key=['game_id', 'team_id']) }}
```

---

## Historisation (SCD type 2)

Le snapshot `snap_team` historise le profil de performance de chaque équipe (win%, ratings
offensif/défensif, pace, true shooting %) : une nouvelle version datée est créée à chaque
exécution du pipeline où ces attributs changent, plutôt que d'écraser la valeur précédente. Le
mécanisme est volontairement basé sur les **runs du pipeline**, pas sur les saisons elles-mêmes
(l'historique multi-saison est déjà porté par `fct_game`) — c'est la façon correcte d'utiliser
un snapshot SCD2 : capturer l'évolution d'un état entre deux chargements, pas encoder un
historique déjà présent dans les faits.

---

## Installation et exécution

```bash
# 1. Base PostgreSQL (le port hôte 5544 est utilisé pour éviter tout conflit avec un
#    Postgres local déjà présent sur 5432 ; adapte-le si besoin dans profiles.yml)
docker compose up -d

# 2. Environnement Python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 3. Chargement des données brutes
python scripts/export_source_data.py   # copie team_stats_history/team_advanced_history depuis NBA-Game-Data
python scripts/fetch_shots.py          # tirs individuels via nba_api ShotChartDetail (saison 2025-26, 30 equipes)
python scripts/load_raw.py             # charge les 3 CSV dans Postgres, schema `raw`

# 4. Config dbt
cp profiles.example.yml ~/.dbt/profiles.yml   # ajuste le mot de passe si besoin
dbt deps    # installe dbt-utils

# 5. Vérification de la connexion
dbt debug

# 6. Exécution des modèles, du seed, du snapshot ET des tests
dbt build

# 7. Documentation et lineage
dbt docs generate
dbt docs serve
```

> `~/.dbt/profiles.yml` contient les identifiants de connexion et **n'est pas versionné** (voir
> `.gitignore`). Un modèle d'exemple est fourni dans `profiles.example.yml`.

---

## Résultats

- **6 modèles** (3 staging, 3 marts), **1 seed**, **1 snapshot**, **15 tests** — `dbt build`
  intégral en **~0,8 s** (petit volume de données, exécution locale).
- Volumes chargés : 2 460 lignes équipe×match, 30 lignes équipe×saison (profil avancé),
  219 160 tirs individuels sur la saison 2025-26.
- Observation tirée de `fct_shot_efficiency` (agrégée par zone, toutes équipes) : l'écart
  d'adresse au tir entre zones est net et cohérent avec la logique du jeu — la zone restreinte
  (`Restricted Area`) tourne à **67 % de réussite en moyenne** (63-74 % selon les équipes, sur
  62 253 tirs), contre **35 % en moyenne pour les tirs à 3 points au-dessus de l'arc**
  (`Above the Break 3`, la zone la plus tentée avec 67 375 tirs) et **41 % pour le mid-range**.
  Ça illustre concrètement pourquoi la sélection de tir (shot selection) pèse autant sur
  l'efficacité offensive globale d'une équipe.

---

## Prochaines étapes

- Étendre `fetch_shots.py` à plusieurs saisons pour permettre une vraie comparaison
  d'évolution de l'adresse au tir dans le temps.
- Ajouter des tests de freshness sur `raw.shots` (actuellement seule `team_game_stats` en a
  un, via `loaded_at_field`).
- Orchestration du run quotidien (ex. cron + les 3 scripts + `dbt build`) pour que `snap_team`
  capture réellement des changements SCD2 au fil des saisons futures.

---

## Auteur

**Nabil Dia** — Master Data Science, Statistiques & IA (EPSI)
[LinkedIn](https://www.linkedin.com/in/mohamed-nabil-dia/) · [Portfolio](https://nabildiaportfolio.netlify.app) · [GitHub](https://github.com/NabilDia)
