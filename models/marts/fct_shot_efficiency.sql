with shots as (

    select * from {{ ref('stg_shots') }}

),

aggregated as (

    select
        team_id,
        season,
        shot_zone_basic,
        count(*) as shots_attempted,
        sum(case when shot_made then 1 else 0 end) as shots_made

    from shots
    group by team_id, season, shot_zone_basic

),

final as (

    select
        team_id,
        season,
        shot_zone_basic,
        shots_attempted,
        shots_made,
        round(shots_made::numeric / nullif(shots_attempted, 0), 4) as fg_pct

    from aggregated

)

select * from final
