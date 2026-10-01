with source as (

    select * from {{ source('raw', 'team_game_stats') }}

),

renamed as (

    select
        game_id,
        team_id,
        team_abbreviation,
        team_name,
        season_year as season,
        to_date(game_date, 'MM/DD/YYYY') as game_date,
        matchup,
        case when wl = 'W' then true when wl = 'L' then false end as is_win,
        min as minutes_played,
        fgm as field_goals_made,
        fga as field_goals_attempted,
        fg_pct as field_goal_pct,
        fg3m as three_pointers_made,
        fg3a as three_pointers_attempted,
        fg3_pct as three_point_pct,
        ftm as free_throws_made,
        fta as free_throws_attempted,
        ft_pct as free_throw_pct,
        oreb as offensive_rebounds,
        dreb as defensive_rebounds,
        reb as total_rebounds,
        ast as assists,
        tov as turnovers,
        stl as steals,
        blk as blocks,
        pf as personal_fouls,
        pts as points,
        plus_minus

    from source

)

select * from renamed
