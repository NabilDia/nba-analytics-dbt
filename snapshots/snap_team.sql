{% snapshot snap_team %}

{{
    config(
        target_schema='snapshots',
        unique_key='team_id',
        strategy='check',
        check_cols=[
            'team_name',
            'win_pct',
            'off_rating',
            'def_rating',
            'net_rating',
            'pace',
            'true_shooting_pct',
        ],
    )
}}

-- Historise le profil de performance de chaque equipe (une ligne par team_id).
-- Une nouvelle version SCD2 est creee quand ces attributs changent entre deux
-- executions du pipeline (ex. apres le chargement d'une saison plus recente).
select * from {{ ref('stg_teams') }}

{% endsnapshot %}
