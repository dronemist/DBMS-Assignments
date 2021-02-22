-- 1 --
select wickets.match_id, player.player_name, team.team_name, wickets.num_wickets from
    (select ball_by_ball.match_id, ball_by_ball.bowler, ball_by_ball.team_bowling, Count(*) as num_wickets from
        (select * from wicket_taken, out_type
        where wicket_taken.kind_out = out_type.out_id and (
        out_type.out_name NOT IN ('run out', 'retired hurt', 'obstructing the field'))
        ) AS bowlers_wickets, 
        ball_by_ball,
        player
    where ball_by_ball.match_id = bowlers_wickets.match_id and
        ball_by_ball.over_id = bowlers_wickets.over_id and
        ball_by_ball.ball_id = bowlers_wickets.ball_id and
        ball_by_ball.innings_no = bowlers_wickets.innings_no and
        ball_by_ball.bowler = player.player_id
    GROUP BY ball_by_ball.match_id, ball_by_ball.bowler, ball_by_ball.team_bowling
    HAVING Count(*) >= 5
    ) AS wickets, player, team 
    where wickets.bowler = player.player_id and 
    team.team_id = wickets.team_bowling
    ORDER BY wickets.num_wickets DESC, player.player_name, team.team_name
;

-- 2 --
select player.player_name, most_mom.num_matches from
    (select player_match.player_id, Count(*) as num_matches from 
        (select match.match_id, match.man_of_the_match, 
        case 
        when match.match_winner = match.team_1 then match.team_2 
        else match.team_1 END 
        as losing_team from 
        match, outcome
        where match.outcome_id = outcome.outcome_id and
        outcome.outcome_type NOT IN ('No Result')
        ) 
    as losing_mom,
    player_match
    where losing_mom.match_id = player_match.match_id and
    losing_mom.man_of_the_match = player_match.player_id and 
    losing_mom.losing_team = player_match.team_id
    group by player_match.player_id) as 
most_mom,
player
where player.player_id = most_mom.player_id
order by most_mom.num_matches DESC, player.player_name
fetch first 3 rows only
;

-- 3 --
with catches(player_id, num_catches) as (
    select wicket_taken.fielders, count(*) as num_catches from 
    wicket_taken,
    match, 
    out_type
    where wicket_taken.kind_out = out_type.out_id and
    match.match_id = wicket_taken.match_id and
    extract(year from  match.match_date) = 2012 and
    out_type.out_name = 'caught'
    group by wicket_taken.fielders
)
select player.player_name, catches.num_catches from 
catches, 
player
where catches.player_id = player.player_id 
order by catches.num_catches DESC, player.player_name
limit 1
;

-- 4 --
with matches_played(season_id, player_id, num_matches) as (
    select match.season_id, player_match.player_id, count(*) as matches_played from
    player_match,
    match
    where player_match.match_id = match.match_id
    group by match.season_id, player_match.player_id
    order by match.season_id
)
select season.season_year, player.player_name, matches_played.num_matches from
player,
season,
matches_played
where season.purple_cap = matches_played.player_id and
season.season_id = matches_played.season_id and
season.purple_cap = player.player_id
order by season.season_year
;

