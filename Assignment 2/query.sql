-- PREAMBLE -- 
create view edge_authors as (
    select a1.authorid as author1, a2.authorid as author2      
    from authorpaperlist as a1, authorpaperlist as a2
    where a1.paperid = a2.paperid and 
    a1.authorid != a2.authorid
    union
    select a2.authorid, a1.authorid        
    from authorpaperlist as a1, authorpaperlist as a2
    where a1.paperid = a2.paperid and
    a1.authorid != a2.authorid
);
create view connected_components as (
    with reachable_list(authorid, list) as (
        with recursive reachable_authors(author1, author2) as (
            select edge_authors.author1, edge_authors.author2
            from edge_authors
        union 
            select edge_authors.author1, reachable_authors.author2 
            from edge_authors, reachable_authors
            where edge_authors.author2 = reachable_authors.author1
        )
        select reachable_authors.author1, 
        array_agg(reachable_authors.author2 order by reachable_authors.author2) 
        from reachable_authors
        group by reachable_authors.author1
    )
    select *, dense_rank() over (order by list) as componenet_id
    from reachable_list
);

-- 1 --
with recursive reachable(airport1, airport2, carrier) as (
        select flights.originairportid, flights.destairportid, flights.carrier from 
        flights
    union
        select flights.originairportid, reachable.airport2, flights.carrier from 
        reachable, flights 
        where flights.destairportid = reachable.airport1 and
        flights.carrier = reachable.carrier
)
select distinct airports.city from
airports, reachable
where reachable.airport1 = 10140 and
reachable.airport2 = airports.airportid 
order by airports.city
;

-- 2 --
with recursive reachable(airport1, airport2, dayofweek) as (
        select flights.originairportid, flights.destairportid, flights.dayofweek from 
        flights
    union
        select flights.originairportid, reachable.airport2, flights.dayofweek from 
        reachable, flights 
        where flights.destairportid = reachable.airport1 and
        flights.dayofweek = reachable.dayofweek
)
select distinct airports.city from
airports, reachable
where reachable.airport1 = 10140 and
reachable.airport2 = airports.airportid 
order by airports.city
;

-- 3 --
with recursive paths(airport1, airport2, paths) as (
        select flights.originairportid, flights.destairportid, array[flights.originairportid, flights.destairportid] from 
        flights
    union
        select flights.originairportid, paths.airport2, array[flights.originairportid] || paths.paths   from 
        paths, flights 
        where flights.destairportid = paths.airport1 and
        flights.originairportid != all(paths.paths)
),
num_paths(airport1, airport2, num_paths) as (
    select airport1, airport2, count(*) from
    paths
    group by airport1, airport2
)
select airports.city from 
airports, num_paths
where num_paths.airport1 = 10140 and
num_paths.airport2 = airports.airportid and
num_paths.num_paths = 1
order by airports.city
;

-- 4 --
with recursive paths(airport1, airport2, paths) as (
        select flights.originairportid, flights.destairportid, array[flights.originairportid, flights.destairportid] from 
        flights
    union
        select flights.originairportid, paths.airport2, array[flights.originairportid] || paths.paths   from 
        paths, flights 
        where flights.destairportid = paths.airport1 and
        flights.originairportid != all(paths.paths)
),
circular_paths(airport1, len) as (
    select flights.originairportid, 1 + array_length(paths.paths, 1) from
    paths, flights
    where flights.destairportid = paths.airport1 and
    flights.originairportid = paths.airport2
)
select len as length 
from circular_paths 
where airport1 = 10140
order by len desc
fetch first 1 rows only
;

-- 5 --
with recursive paths(airport1, airport2, paths) as (
        select flights.originairportid, flights.destairportid, array[flights.originairportid, flights.destairportid] from 
        flights
    union
        select flights.originairportid, paths.airport2, array[flights.originairportid] || paths.paths   from 
        paths, flights 
        where flights.destairportid = paths.airport1 and
        flights.originairportid != all(paths.paths)
),
circular_paths(airport1, len) as (
    select flights.originairportid, 1 + array_length(paths.paths, 1) from
    paths, flights
    where flights.destairportid = paths.airport1 and
    flights.originairportid = paths.airport2
)
select len as length 
from circular_paths 
order by len desc
fetch first 1 rows only
;

-- 6 --
with recursive edge(airport1, airport2) as (
    select flights.originairportid, flights.destairportid from 
    flights, airports as a1, airports as a2
    where a1.airportid = flights.destairportid and
    a2.airportid = flights.originairportid and
    a1.state != a2.state
),
paths(airport1, airport2, paths) as (
        select edge.airport1, edge.airport2, array[edge.airport1, edge.airport2] from 
        edge
    union
        select edge.airport1, paths.airport2, array[edge.airport1] || paths.paths   from 
        paths, edge
        where edge.airport2 = paths.airport1 and
        edge.airport1 != all(paths.paths)
),
num_paths(airport1, airport2, num_paths) as (
    select airport1, airport2, count(*) from
    paths
    group by airport1, airport2
)
select num_paths as count from 
num_paths, airports as a1, airports as a2 
where num_paths.airport1 = a1.airportid and
num_paths.airport2 = a2.airportid and 
a1.city = 'Albuquerque' and
a2.city = 'Chicago' 
; 

-- 7 -- 
with recursive paths(airport1, airport2, paths, contains) as (
        select flights.originairportid, flights.destairportid, array[flights.originairportid, flights.destairportid],
        case when a1.city = 'Washington' or a2.city = 'Washington' then 1 else 0 end
        from 
        flights, airports as a1, airports as a2
        where a1.airportid = flights.destairportid and
        a2.airportid = flights.originairportid
    union
        select flights.originairportid, paths.airport2, array[flights.originairportid] || paths.paths, 
        case when a1.city = 'Washington' or paths.contains = 1 then 1 else 0 end
        from 
        paths, flights, airports as a1
        where flights.destairportid = paths.airport1 and
        flights.originairportid != all(paths.paths) and 
        a1.airportid = flights.originairportid
),
num_paths(airport1, airport2, num_paths) as (
    select airport1, airport2, count(*) from
    paths
    where paths.contains = 1
    group by airport1, airport2
)
select num_paths as count from 
num_paths, airports as a1, airports as a2 
where num_paths.airport1 = a1.airportid and
num_paths.airport2 = a2.airportid and 
a1.city = 'Albuquerque' and
a2.city = 'Chicago' 
; 

-- 8 --
with recursive reachable(airport1, airport2) as (
        select flights.originairportid, flights.destairportid from 
        flights
    union
        select flights.originairportid, reachable.airport2 from 
        reachable, flights 
        where flights.destairportid = reachable.airport1
), 
all_pairs(airport1, airport2, reachable) as (
    select a1.airportid, a2.airportid,
    case when exists(
        select * from reachable 
        where reachable.airport1 = a1.airportid and 
        reachable.airport2 = a2.airportid
    ) then 1 else 0 end
    from 
    airports as a1, airports as a2
    where a1.airportid != a2.airportid
)
select a1.city as name1, a2.city as name2 from 
all_pairs, airports as a1, airports as a2 
where a1.airportid = all_pairs.airport1 and
a2.airportid = all_pairs.airport2 and
all_pairs.reachable != 1
order by a1.city, a2.city
; 

-- 9 --
with delays(airportid, day, delay) as (
    select flights.originairportid, flights.dayofmonth, sum(flights.arrivaldelay) + sum(flights.departuredelay) from 
    flights
    group by flights.originairportid, flights.dayofmonth
)
select delays.day from 
delays, airports
where airports.airportid = delays.airportid and
airports.city = 'Albuquerque'
order by delays.delay, delays.day
;

-- 10 --
with num_cities(num_cities) as (
    select count(distinct airports.city) from
    airports 
    where 
    airports.state = 'New York'
),
num_cities_covered(city, num_cities) as (
    select a1.city, count(distinct a2.city) from 
    flights, airports as a1, airports as a2
    where 
    flights.originairportid = a1.airportid and
    flights.destairportid = a2.airportid and
    a1.state = 'New York' and
    a2.state = 'New York'
    group by a1.city
)
select city from 
num_cities_covered, num_cities
where num_cities_covered.num_cities = num_cities.num_cities - 1
;

-- 11 --
with recursive paths(airport1, airport2, paths, last_delay) as (
        select flights.originairportid, flights.destairportid, 
        array[flights.originairportid, flights.destairportid],
        flights.arrivaldelay + flights.departuredelay
        from flights
    union
        select flights.originairportid, paths.airport2, array[flights.originairportid] || paths.paths,
        flights.arrivaldelay + flights.departuredelay
        from paths, flights 
        where flights.destairportid = paths.airport1 and
        flights.originairportid != all(paths.paths) and 
        flights.arrivaldelay + flights.departuredelay <= paths.last_delay
)
select a1.city, a2.city from 
paths, airports as a1, airports as a2
where a1.airportid = paths.airport1 and
a2.airportid = paths.airport2
order by a1.city, a2.city
;

-- 12 --
with recursive paths(author1, author2, paths) as (
        select author1, author2, array[author1, author2] from
        edge_authors
    union 
        select edge_authors.author1, paths.author2, array[edge_authors.author1] || paths.paths
        from edge_authors, paths
        where edge_authors.author2 = paths.author1 and
        edge_authors.author1 != all(paths.paths)
),
shortest_path(author1, author2, length) as (
    select author1, author2, min(array_length(paths, 1) - 1)
    from paths
    group by author1, author2
),
all_pairs(author1, author2, length) as (
    select a1.authorid, a2.authorid, 
    coalesce((select length from shortest_path 
        where a1.authorid = shortest_path.author1 and
        a2.authorid = shortest_path.author2), -1)
    from authordetails as a1, authordetails as a2    
    where a1.authorid != a2.authorid
)
select authorid, length 
from all_pairs, authordetails 
where authorid = author2 and
author1 = 1235
order by length desc, authorid;

-- 13 --
with num_paths (author1, author2, count) as (
    with recursive paths(author1, author2, paths, last_gender) as (
            select author1, author2, array[author1, author2], null from
            edge_authors
        union 
            select edge_authors.author1, paths.author2, 
            array[edge_authors.author1] || paths.paths, a2.gender
            from edge_authors, paths, authordetails as a2
            where edge_authors.author2 = paths.author1 and
            edge_authors.author1 != all(paths.paths) and
            paths.paths[1] = a2.authorid and
            a2.age > 35 and
            (
                case when paths.last_gender is null then true
                else paths.last_gender != a2.gender
                end
            )
    )
    select author1, author2, count(*) from
    paths
    group by author1, author2
)
select 
    (case 
    when a1.componenet_id != a2.componenet_id then -1
    else coalesce(
        (select num_paths.count from num_paths
            where num_paths.author1 = a1.authorid and
            num_paths.author2 = a2.authorid
        ), 0)
    end) as count, a1.authorid, a2.authorid
from connected_components as a1, connected_components as a2
where a1.authorid = 1558 and
a2.authorid = 2826
;

-- 14 --


-- CLEANUP --
drop view connected_components cascade;
drop view edge_authors cascade;
