with source as (

    select * from {{ source('raw', 'shots') }}

),

renamed as (

    select
        game_id,
        game_event_id,
        player_id,
        player_name,
        team_id,
        team_name,
        '{{ var("shot_season") }}' as season,
        to_date(game_date::text, 'YYYYMMDD') as game_date,
        period,
        action_type,
        shot_type,
        shot_zone_basic,
        shot_zone_area,
        shot_zone_range,
        shot_distance,
        loc_x,
        loc_y,
        (shot_made_flag = 1) as shot_made

    from source

)

select * from renamed
