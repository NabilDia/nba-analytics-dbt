{{
    config(
        materialized='incremental',
        unique_key=['game_id', 'team_id']
    )
}}

with games as (

    select * from {{ ref('stg_games') }}

)

select
    game_id,
    team_id,
    season,
    game_date,
    matchup,
    is_win,
    minutes_played,
    field_goals_made,
    field_goals_attempted,
    field_goal_pct,
    three_pointers_made,
    three_pointers_attempted,
    three_point_pct,
    free_throws_made,
    free_throws_attempted,
    free_throw_pct,
    offensive_rebounds,
    defensive_rebounds,
    total_rebounds,
    assists,
    turnovers,
    steals,
    blocks,
    personal_fouls,
    points,
    plus_minus

from games

{% if is_incremental() %}
where game_date > (select coalesce(max(game_date), '1900-01-01') from {{ this }})
{% endif %}
