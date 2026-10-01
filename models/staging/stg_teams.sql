with source as (

    select * from {{ source('raw', 'team_advanced_stats') }}

),

renamed as (

    select
        team_id,
        team_name,
        season,
        gp as games_played,
        w as wins,
        l as losses,
        w_pct as win_pct,
        off_rating,
        def_rating,
        net_rating,
        pace,
        ts_pct as true_shooting_pct,
        row_number() over (partition by team_id order by season desc) as season_recency_rank

    from source

),

-- une ligne par equipe : le profil de performance le plus recent.
-- l'historique multi-saison reste porte par fct_game ; ce modele nourrit
-- dim_team et snap_team, qui n'ont de sens qu'a une seule ligne par team_id.
most_recent_per_team as (

    select
        team_id,
        team_name,
        season,
        games_played,
        wins,
        losses,
        win_pct,
        off_rating,
        def_rating,
        net_rating,
        pace,
        true_shooting_pct

    from renamed
    where season_recency_rank = 1

)

select * from most_recent_per_team
