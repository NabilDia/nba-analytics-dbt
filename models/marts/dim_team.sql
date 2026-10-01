with teams as (

    select * from {{ ref('stg_teams') }}

),

team_ref as (

    select * from {{ ref('team_reference') }}

),

final as (

    select
        teams.team_id,
        teams.team_name,
        teams.season as latest_season,
        team_ref.conference,
        team_ref.division,
        teams.games_played,
        teams.wins,
        teams.losses,
        teams.win_pct,
        teams.off_rating,
        teams.def_rating,
        teams.net_rating,
        teams.pace,
        teams.true_shooting_pct

    from teams
    left join team_ref on teams.team_id = team_ref.team_id

)

select * from final
