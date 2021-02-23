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
select player.player_name from 
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

-- 5 --
with runs_scored(match_id, player_id, runs_scored) as (
    select batsman_scored.match_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no
    group by batsman_scored.match_id, ball_by_ball.striker
),
losing_team(match_id, losing_team) as (
    select match.match_id,
    case 
    when match.match_winner = match.team_1 then match.team_2 
    else match.team_1 END 
    as losing_team from 
    match, outcome
    where match.outcome_id = outcome.outcome_id and
    outcome.outcome_type != 'No Result'
) 
select distinct player.player_name from 
losing_team,
runs_scored,
player_match,
player
where runs_scored.match_id = losing_team.match_id and
runs_scored.match_id = player_match.match_id and
runs_scored.player_id = player_match.player_id and
runs_scored.player_id = player.player_id and
player_match.team_id = losing_team.losing_team and 
runs_scored.runs_scored > 50
order by player.player_name
;

-- 6 --
with left_handed_batsmen(season_id, team_id, team_name, player_id) as (
    select distinct match.season_id, player_match.team_id, team.team_name, player_match.player_id from
    player_match,
    player,
    batting_style,
    country,
    match,
    team
    where player_match.player_id = player.player_id and
    player.batting_hand = batting_style.batting_id and
    batting_style.batting_hand = 'Left-hand bat' and
    player.country_id = country.country_id and
    country.country_name != 'India' and 
    player_match.match_id = match.match_id and
    team.team_id = player_match.team_id
), 
left_handed_batsmen_ranked(season_id, team_id, team_name, rank) as (
    select season_id, team_id, team_name, rank() over (partition by season_id order by count(*) DESC, team_name) from
    left_handed_batsmen
    group by season_id, team_id, team_name
)
select season.season_year, left_handed_batsmen_ranked.team_name, left_handed_batsmen_ranked.rank from 
left_handed_batsmen_ranked,
season
where season.season_id = left_handed_batsmen_ranked.season_id and
left_handed_batsmen_ranked.rank <= 5
order by season.season_year, rank
;

-- 7 --
with match_winner(match_id, winner) as (
    select match.match_id, match.match_winner from 
    match, 
    season,
    outcome
    where match.season_id = season.season_id and
    season.season_year = 2009 and 
    outcome.outcome_id = match.outcome_id and
    outcome.outcome_type != 'No Result'
) 
select team.team_name from 
match_winner,
team
where match_winner.winner = team.team_id
group by match_winner.winner, team.team_name
order by count(*) DESC, team.team_name;
;

8 --
with runs_scored(match_id, player_id, runs_scored) as (
    select batsman_scored.match_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no
    group by batsman_scored.match_id, ball_by_ball.striker
), 
runs_scored_season(season_id, team_id, player_id, runs_scored) as (
    select match.season_id, player_match.team_id, runs_scored.player_id, sum(runs_scored.runs_scored)
    from runs_scored, 
    match,
    player_match
    where runs_scored.match_id = match.match_id and
    runs_scored.player_id = player_match.player_id and
    runs_scored.match_id = player_match.match_id
    group by match.season_id, player_match.team_id, runs_scored.player_id
)
select team_name, player_name, runs_scored from (
    select team.team_name, player.player_name, runs_scored_season.runs_scored,  
    rank() over (partition by runs_scored_season.season_id, runs_scored_season.team_id order by runs_scored_season.runs_scored DESC, player.player_name) as rank
    from runs_scored_season,
    team,
    season,  
    player
    where runs_scored_season.player_id = player.player_id and
    team.team_id = runs_scored_season.team_id and
    season.season_id = runs_scored_season.season_id and
    season.season_year = 2010
) t 
where t.rank = 1
order by team_name
;

9 --
with num_sixes(match_id, team_id, innings_no, sixes) as (
    select batsman_scored.match_id, ball_by_ball.team_batting, ball_by_ball.innings_no, 
    sum(case when batsman_scored.runs_scored = 6 then 1 else 0 end) as sixes from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no
    group by batsman_scored.match_id, ball_by_ball.team_batting, ball_by_ball.innings_no
)
select team_name, opponent_team_name, sixes from (
    select t1.team_name as team_name, t2.team_name as opponent_team_name, num_sixes.sixes, 
    rank() over(partition by season.season_id order by num_sixes.sixes desc, t1.team_name) as rank
    from team as t1,
    team as t2, 
    num_sixes,
    match,
    season
    where num_sixes.team_id = t1.team_id and
    match.match_id = num_sixes.match_id and
    match.season_id = season.season_id and 
    season.season_year = 2008 and
    (
        case 
        when num_sixes.team_id = match.team_1 then t2.team_id = match.team_2
        else t2.team_id = match.team_1 
        end 
    )
) temp 
where rank <= 3
;