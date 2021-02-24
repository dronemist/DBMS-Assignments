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
        ball_by_ball.innings_no <= 2 and
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
    wicket_taken.innings_no <= 2 and
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
    batsman_scored.innings_no = ball_by_ball.innings_no and 
    ball_by_ball.innings_no <= 2
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

-- 8 --
with runs_scored(match_id, player_id, runs_scored) as (
    select batsman_scored.match_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    batsman_scored.innings_no <= 2
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
select team_name, player_name, runs_scored as runs from (
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

-- 9 --
with num_sixes(match_id, team_id, innings_no, sixes) as (
    select batsman_scored.match_id, ball_by_ball.team_batting, ball_by_ball.innings_no, 
    sum(case when batsman_scored.runs_scored = 6 then 1 else 0 end) as sixes from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    batsman_scored.innings_no <= 2
    group by batsman_scored.match_id, ball_by_ball.team_batting, ball_by_ball.innings_no
)
select team_name, opponent_team_name, sixes as number_of_sixes from (
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
order by rank
;

-- 10 --
with num_wickets(player_id, num_wickets) as (
    select ball_by_ball.bowler as player_id, Count(*) as num_wickets from
        (select * from wicket_taken, out_type
        where wicket_taken.kind_out = out_type.out_id and (
        out_type.out_name NOT IN ('run out', 'retired hurt', 'obstructing the field'))
        ) AS bowlers_wickets, 
        ball_by_ball
    where ball_by_ball.match_id = bowlers_wickets.match_id and
        ball_by_ball.over_id = bowlers_wickets.over_id and
        ball_by_ball.ball_id = bowlers_wickets.ball_id and
        ball_by_ball.innings_no = bowlers_wickets.innings_no and
        ball_by_ball.innings_no <= 2
    group by ball_by_ball.bowler
), 
average_bowlers(bowling_id, bowling_skill, average) as (
    select bowling_style.bowling_id, bowling_style.bowling_skill, avg(num_wickets.num_wickets) from 
    bowling_style, 
    num_wickets,
    player
    where num_wickets.player_id = player.player_id and
    player.bowling_skill = bowling_style.bowling_id
    group by bowling_style.bowling_id, bowling_style.bowling_skill
), 
runs_scored(match_id, player_id, runs_scored) as (
    select batsman_scored.match_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    ball_by_ball.innings_no <= 2
    group by batsman_scored.match_id, ball_by_ball.striker
), 
batting_average(player_id, average) as (
    select player_id, avg(runs_scored) 
    from runs_scored
    group by player_id
)
select bowling_skill, player_name, batting_average from (
    select average_bowlers.bowling_skill, player.player_name, batting_average.average as batting_average, average_bowlers.average, num_wickets.num_wickets,
    rank() over (partition by average_bowlers.bowling_id order by batting_average.average desc, player.player_name) as rank
    from average_bowlers, player, num_wickets, batting_average
    where player.player_id = batting_average.player_id and
    player.player_id = num_wickets.player_id and
    player.bowling_skill = average_bowlers.bowling_id and
    num_wickets.num_wickets > all (select average from average_bowlers)
) temp
where rank = 1
order by bowling_skill, rank
;

-- 11 -- 
with num_wickets(season_id, player_id, num_wickets) as (
    select match.season_id, ball_by_ball.bowler as player_id, Count(*) as num_wickets from
        (select * from wicket_taken, out_type
        where wicket_taken.kind_out = out_type.out_id and (
        out_type.out_name NOT IN ('run out', 'retired hurt', 'obstructing the field'))
        ) AS bowlers_wickets, 
        ball_by_ball,
        match
    where ball_by_ball.match_id = bowlers_wickets.match_id and
        ball_by_ball.over_id = bowlers_wickets.over_id and
        ball_by_ball.ball_id = bowlers_wickets.ball_id and
        ball_by_ball.innings_no = bowlers_wickets.innings_no and 
        ball_by_ball.innings_no <= 2 and
        ball_by_ball.match_id = match.match_id
    group by match.season_id, ball_by_ball.bowler
), 
runs_scored(season_id, player_id, runs_scored) as (
    select match.season_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball,
    match
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    batsman_scored.innings_no <= 2 and
    batsman_scored.match_id = match.match_id
    group by match.season_id, ball_by_ball.striker
), 
matches_played(season_id, player_id, num_matches) as (
    select match.season_id, player_match.player_id, count(*) as matches_played from
    player_match,
    match
    where player_match.match_id = match.match_id
    group by match.season_id, player_match.player_id
)
select season.season_year, player.player_name, num_wickets.num_wickets, runs_scored.runs_scored as runs from 
season, player, num_wickets, matches_played, runs_scored, batting_style
where player.player_id = matches_played.player_id and
player.player_id = num_wickets.player_id and
player.player_id = runs_scored.player_id  and
season.season_id = matches_played.season_id  and
season.season_id = runs_scored.season_id and
season.season_id = num_wickets.season_id and
player.batting_hand = batting_style.batting_id and
batting_style.batting_hand = 'Left-hand bat' and
runs_scored.runs_scored >= 150 and
num_wickets.num_wickets >= 5 and
matches_played.num_matches >= 10
order by num_wickets.num_wickets desc, runs_scored.runs_scored desc, player.player_name 
;

-- 12 --
with num_wickets(match_id, player_id, num_wickets) as (
    select ball_by_ball.match_id, ball_by_ball.bowler as player_id, Count(*) as num_wickets from
        (select * from wicket_taken, out_type
        where wicket_taken.kind_out = out_type.out_id and (
        out_type.out_name NOT IN ('run out', 'retired hurt', 'obstructing the field'))
        ) AS bowlers_wickets, 
        ball_by_ball
    where ball_by_ball.match_id = bowlers_wickets.match_id and
        ball_by_ball.over_id = bowlers_wickets.over_id and
        ball_by_ball.ball_id = bowlers_wickets.ball_id and
        ball_by_ball.innings_no = bowlers_wickets.innings_no and
        ball_by_ball.innings_no <= 2
    group by ball_by_ball.match_id, ball_by_ball.bowler
)
select match_id, player_name, team_name, num_wickets, season_year from (
    select match.match_id, player.player_name, team.team_name, num_wickets.num_wickets, season.season_year,
    rank() over (order by num_wickets desc, player.player_name, match.match_id) as rank from
    match, player, num_wickets, season, team, player_match
    where match.match_id = num_wickets.match_id and
    player.player_id = num_wickets.player_id and
    player_match.player_id = num_wickets.player_id and
    player_match.match_id = num_wickets.match_id and
    player_match.team_id = team.team_id and
    match.season_id = season.season_id
) temp 
where rank = 1
;

-- 13 --
with matches_played(season_id, player_id, num_matches) as (
    select match.season_id, player_match.player_id, count(*) as matches_played from
    player_match,
    match
    where player_match.match_id = match.match_id
    group by match.season_id, player_match.player_id
),
seasons_played(player_id, seasons_played) as (
    select player_id, count(*) as seasons_played from 
    matches_played
    group by player_id
)
select player.player_name from 
seasons_played, player
where player.player_id = seasons_played.player_id and
seasons_played.seasons_played = (select count(*) from season)
order by player.player_name 
;

-- 14 --
with runs_scored(match_id, player_id, runs_scored) as (
    select batsman_scored.match_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    ball_by_ball.innings_no <= 2
    group by batsman_scored.match_id, ball_by_ball.striker
),
most_fifty_winning(match_id, team_id, num_fifty) as (
    select runs_scored.match_id, player_match.team_id, count(*) as num_fifty from
    runs_scored, player_match, match
    where runs_scored.player_id = player_match.player_id and
    runs_scored.match_id = player_match.match_id and
    runs_scored.runs_scored >= 50 and
    match.match_id = player_match.match_id and
    match.match_winner = player_match.team_id
    group by runs_scored.match_id, player_match.team_id
)
select season_year, match_id, team_name from (
    select season.season_year, most_fifty_winning.match_id, team.team_name,
    rank() over(partition by season.season_id order by most_fifty_winning.num_fifty desc, team.team_name) as rank
    from season, most_fifty_winning, team, match
    where match.match_id = most_fifty_winning.match_id and
    most_fifty_winning.team_id = team.team_id and
    season.season_id = match.season_id 
) temp
where rank <= 3
order by season_year, rank;

-- 15 --
with num_wickets(season_id, player_id, num_wickets) as (
    select match.season_id, ball_by_ball.bowler as player_id, Count(*) as num_wickets from
        (select * from wicket_taken, out_type
        where wicket_taken.kind_out = out_type.out_id and (
        out_type.out_name NOT IN ('run out', 'retired hurt', 'obstructing the field'))
        ) AS bowlers_wickets, 
        ball_by_ball,
        match
    where ball_by_ball.match_id = bowlers_wickets.match_id and
        ball_by_ball.over_id = bowlers_wickets.over_id and
        ball_by_ball.ball_id = bowlers_wickets.ball_id and
        ball_by_ball.innings_no = bowlers_wickets.innings_no and 
        ball_by_ball.innings_no <= 2 and
        ball_by_ball.match_id = match.match_id
    group by match.season_id, ball_by_ball.bowler
), 
runs_scored(season_id, player_id, runs_scored) as (
    select match.season_id, ball_by_ball.striker, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball,
    match
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    batsman_scored.innings_no <= 2 and
    batsman_scored.match_id = match.match_id
    group by match.season_id, ball_by_ball.striker
)
select season.season_year, p2.player_name as top_batsmen, t2.runs_scored as max_runs, p1.player_name as top_bowler, t1.num_wickets as max_wickets from (
    select num_wickets.season_id, num_wickets.player_id, num_wickets.num_wickets,
    rank() over(partition by num_wickets.season_id order by num_wickets.num_wickets desc, player.player_name) from
    num_wickets, player
    where num_wickets.player_id = player.player_id
) t1, (
    select runs_scored.season_id, runs_scored.player_id, runs_scored.runs_scored,
    rank() over(partition by runs_scored.season_id order by runs_scored.runs_scored desc, player.player_name) from
    runs_scored, player
    where runs_scored.player_id = player.player_id
) t2, player as p1, player as p2, season 
where t1.season_id = t2.season_id and
season.season_id = t1.season_id and
p2.player_id = t2.player_id and
p1.player_id = t1.player_id and
t1.rank = 2 and
t2.rank = 2
order by t1.season_id
;

-- 16 --
with result(match_id, winner, loser) as (
    select match.match_id, match.match_winner as winner, (
        case when match.match_winner = match.team_1 then match.team_2
        else match.team_1
        end
    ) as loser
    from match, outcome
    where match.outcome_id = outcome.outcome_id and
    outcome.outcome_type != 'No Result'
), 
matches_won(team_id, num_matches) as (
    select result.winner, count(*) as num_matches
    from result, season, match, team
    where result.match_id = match.match_id and
    season.season_id = match.season_id and
    season.season_year = 2008 and 
    result.loser = team.team_id and
    team.team_name = 'Royal Challengers Bangalore'
    group by result.winner
)
select team.team_name
from matches_won, team
where matches_won.team_id = team.team_id
order by matches_won.num_matches desc, team.team_name
;

-- 17 --
with num_mom(team_id, player_id, num_awards) as (
    select player_match.team_id, player_match.player_id, count(*) as num_awards from
    player_match, match
    where player_match.match_id = match.match_id and
    player_match.player_id = match.man_of_the_match
    group by player_match.team_id, player_match.player_id
)
select team.team_name, temp.player_name, temp.num_awards as count  from (
    select num_mom.team_id, player.player_name, num_mom.num_awards, 
    rank() over(partition by num_mom.team_id order by num_mom.num_awards desc, player.player_name) as rank 
    from num_mom, player
    where player.player_id = num_mom.player_id
) temp, team
where team.team_id = temp.team_id and
temp.rank = 1
order by team.team_name
;

-- 18 --
with run_conceded(match_id, over_id, innings_no, player_id, runs) as (
    select batsman_scored.match_id, ball_by_ball.over_id, ball_by_ball.innings_no, ball_by_ball.bowler, sum(batsman_scored.runs_scored) as runs
    from batsman_scored, ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no
    group by batsman_scored.match_id, ball_by_ball.bowler, ball_by_ball.over_id, ball_by_ball.innings_no
),
matches_played(team_id, player_id, num_matches) as (
    select player_match.team_id, player_match.player_id, count(*) as num_matches from
    player_match
    group by player_match.team_id, player_match.player_id
),
num_teams(player_id, num_teams) as (
    select matches_played.player_id, count(*) as num_teams
    from matches_played
    group by player_id
),
num_run_conceded(player_id, num) as (
    select player_id, count(*) as num
    from run_conceded
    where runs > 20
    group by player_id
)
select player_name from (
    select player.player_name, num_run_conceded.num, num_teams.num_teams,
    rank() over (order by num_run_conceded.num desc, player.player_name) as rank
    from player, num_run_conceded, num_teams
    where player.player_id = num_run_conceded.player_id and
    player.player_id = num_teams.player_id and
    num_teams.num_teams >= 3
) temp
where rank <= 5
order by rank;

-- 19 --
with runs_scored(match_id, team_id, runs_scored) as (
    select batsman_scored.match_id, player_match.team_id, sum(batsman_scored.runs_scored) as runs_scored from
    batsman_scored,
    ball_by_ball,
    player_match
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    ball_by_ball.innings_no <= 2 and
    player_match.match_id = batsman_scored.match_id and
    player_match.player_id = ball_by_ball.striker
    group by batsman_scored.match_id, player_match.team_id
),
average_runs(team_id, average) as (
    select team_id, round(avg(runs_scored), 2) as average from
    runs_scored, match, season
    where runs_scored.match_id = match.match_id and
    match.season_id = season.season_id and
    season.season_year = 2010
    group by team_id
)
select team.team_name, average_runs.average as avg_runs from
team, average_runs
where team.team_id = average_runs.team_id
order by team.team_name;

-- 20 --
with num_out(player_id, num) as (
    select wicket_taken.player_out, count(*) as num
    from wicket_taken
    where wicket_taken.over_id <= 1 and
    wicket_taken.innings_no <= 2
    group by wicket_taken.player_out
)
select player_name as player_names from (
    select player.player_name, num_out.num,
    rank() over(order by num_out.num desc, player.player_name) from 
    player, num_out
    where num_out.player_id = player.player_id
) temp
where rank <= 10
order by rank
;

-- 21 --
with boundaries_scored(match_id, team_id, boundaries) as (
    select batsman_scored.match_id, ball_by_ball.team_batting, 
    sum(case when batsman_scored.runs_scored in (4,6) then 1 else 0 end) as boundaries from
    batsman_scored,
    ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    batsman_scored.innings_no = 2
    group by batsman_scored.match_id, ball_by_ball.team_batting
)
select match_id, team_1_name, team_2_name, match_winner_name, number_of_boundaries from (
    select match.match_id, t1.team_name as team_1_name, t2.team_name as team_2_name, 
    t3.team_name as match_winner_name, boundaries_scored.boundaries as number_of_boundaries,
    rank() over (order by boundaries_scored.boundaries, t3.team_name, t1.team_name, t2.team_name) as rank
    from match, boundaries_scored, team as t1, team as t2, team as t3
    where t1.team_id = match.team_1 and
    t2.team_id = match.team_2 and
    t3.team_id = match.match_winner and 
    match.match_id = boundaries_scored.match_id and
    match.match_winner = boundaries_scored.team_id
) temp
where rank <= 3
order by rank;

-- 22 --
with run_conceded(player_id, runs) as (
    select ball_by_ball.bowler, sum(batsman_scored.runs_scored) as runs
    from batsman_scored, ball_by_ball
    where batsman_scored.match_id = ball_by_ball.match_id and
    batsman_scored.over_id = ball_by_ball.over_id and
    batsman_scored.ball_id = ball_by_ball.ball_id and
    batsman_scored.innings_no = ball_by_ball.innings_no and
    batsman_scored.innings_no <= 2
    group by ball_by_ball.bowler
),
num_wickets(player_id, num_wickets) as (
    select ball_by_ball.bowler as player_id, Count(*) as num_wickets from
        (select * from wicket_taken, out_type
        where wicket_taken.kind_out = out_type.out_id and (
        out_type.out_name NOT IN ('run out', 'retired hurt', 'obstructing the field'))
        ) AS bowlers_wickets, 
        ball_by_ball
    where ball_by_ball.match_id = bowlers_wickets.match_id and
        ball_by_ball.over_id = bowlers_wickets.over_id and
        ball_by_ball.ball_id = bowlers_wickets.ball_id and
        ball_by_ball.innings_no = bowlers_wickets.innings_no and
        ball_by_ball.innings_no <= 2
    group by ball_by_ball.bowler
)
select country_name from (
    select country.country_name, player.player_name, num_wickets.num_wickets, run_conceded.runs,
    cast(run_conceded.runs as decimal) / num_wickets.num_wickets as average, 
    rank() over (order by cast(run_conceded.runs as decimal) / num_wickets.num_wickets, player.player_name) as rank
    from num_wickets, run_conceded, player, country
    where player.player_id = num_wickets.player_id and
    player.player_id = run_conceded.player_id and
    player.country_id = country.country_id
) temp
where rank <= 3
order by rank;

-- TODO -> LOOK AT 10TH AND 14TH