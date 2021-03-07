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

create view edge_authors_conf as (
    select a1.authorid as author1, a1.authorid as author2, p1.conferencename as conference
    from authorpaperlist as a1, paperdetails as p1
    where a1.paperid = p1.paperid
    union
    select a1.authorid as author1, a2.authorid as author2, p1.conferencename as conference    
    from authorpaperlist as a1, authorpaperlist as a2, paperdetails as p1
    where a1.paperid = a2.paperid and 
    p1.paperid = a1.paperid and
    a1.authorid != a2.authorid
    union
    select a2.authorid as author1, a1.authorid as author2, p1.conferencename as conference
    from authorpaperlist as a1, authorpaperlist as a2, paperdetails as p1
    where a1.paperid = a2.paperid and 
    p1.paperid = a1.paperid and
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

create view papers_cited(authorid, papers_cited) as (
    with recursive reachable(paper1, paper2) as (
            select paperid1, paperid2 from 
            citationlist
        union
            select citationlist.paperid1, reachable.paper2 from
            reachable, citationlist
            where citationlist.paperid2 = reachable.paper1
    )
    select distinct authorid, reachable.paper2
    from reachable, authorpaperlist
    where authorpaperlist.paperid = reachable.paper1
);

create view author_citation(paperid, authorid) as (
    with recursive reachable(paper1, paper2) as (
            select paperid1, paperid2 from 
            citationlist
        union
            select citationlist.paperid1, reachable.paper2 from
            reachable, citationlist
            where citationlist.paperid2 = reachable.paper1
    )
    select reachable.paper1, authorid
    from reachable, authorpaperlist
    where reachable.paper2 = authorpaperlist.paperid
)
;

-- 1 --
with recursive reachable(airport1, airport2, carrier) as (
        select flights.originairportid, flights.destairportid, flights.carrier from 
        flights where
        flights.originairportid = 10140
    union
        select reachable.airport1, flights.destairportid, reachable.carrier from 
        reachable, flights 
        where flights.originairportid = reachable.airport2 and
        flights.carrier = reachable.carrier
)
select distinct airports.city as name from
airports, reachable
where reachable.airport1 = 10140 and
reachable.airport2 = airports.airportid 
order by airports.city
;

-- 2 --
with recursive reachable(airport1, airport2, dayofweek) as (
        select flights.originairportid, flights.destairportid, flights.dayofweek from 
        flights where
        flights.originairportid = 10140
    union
        select reachable.airport1, flights.destairportid, reachable.dayofweek from 
        reachable, flights 
        where flights.originairportid = reachable.airport2 and
        flights.dayofweek = reachable.dayofweek
)
select distinct airports.city as name from
airports, reachable
where reachable.airport1 = 10140 and
reachable.airport2 = airports.airportid 
order by airports.city
;

-- 3 --
with recursive paths(airport1, airport2, paths) as (
        select flights.originairportid, flights.destairportid, array[flights.originairportid, flights.destairportid] from 
        flights where
        flights.originairportid = 10140
    union
        select paths.airport1, flights.destairportid, paths.paths || array[flights.destairportid]   from 
        paths, flights 
        where flights.originairportid = paths.airport2 and
        flights.destairportid != all(paths.paths)
),
num_paths(airport1, airport2, num_paths) as (
    select airport1, airport2, count(*) from
    paths
    group by airport1, airport2
)
select airports.city as name from 
airports, num_paths
where num_paths.airport1 = 10140 and
num_paths.airport2 = airports.airportid and
num_paths.num_paths = 1
order by airports.city
;

-- 4 --
with recursive paths(airport1, airport2, paths) as (
        select flights.originairportid, flights.destairportid, array[flights.originairportid, flights.destairportid] from 
        flights where
        flights.originairportid = 10140
    union
        select paths.airport1, flights.destairportid, paths.paths || array[flights.destairportid]   from 
        paths, flights 
        where flights.originairportid = paths.airport2 and
        flights.destairportid != all(paths.paths)
),
circular_paths(airport1, len) as (
    select paths.airport1, array_length(paths.paths, 1) from
    paths, flights
    where flights.destairportid = paths.airport1 and
    flights.originairportid = paths.airport2
)
select coalesce(
    (select len as length 
    from circular_paths 
    where airport1 = 10140
    order by len desc
    fetch first 1 rows only), 0)
as length
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
    select flights.originairportid, array_length(paths.paths, 1) from
    paths, flights
    where flights.destairportid = paths.airport1 and
    flights.originairportid = paths.airport2
)
select coalesce ( 
    (select len as length 
    from circular_paths 
    order by len desc
    fetch first 1 rows only), 0)
    as length
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
select coalesce(
    (select num_paths as count from 
    num_paths, airports as a1, airports as a2 
    where num_paths.airport1 = a1.airportid and
    num_paths.airport2 = a2.airportid and 
    a1.city = 'Albuquerque' and
    a2.city = 'Chicago'), 0)
    as count 
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
select coalesce(
    (select num_paths as count from 
    num_paths, airports as a1, airports as a2 
    where num_paths.airport1 = a1.airportid and
    num_paths.airport2 = a2.airportid and 
    a1.city = 'Albuquerque' and
    a2.city = 'Chicago'), 0 
) as count
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
with recursive delays(airportid, day, delay) as (
    select flights.originairportid, flights.dayofmonth, sum(flights.arrivaldelay) + sum(flights.departuredelay) from 
    flights
    group by flights.originairportid, flights.dayofmonth
), 
day(day) as (
    select 1
    union
    select day + 1 from day where day <= 30
)
select day.day, coalesce(
    (select delays.delay from 
    delays, airports
    where airports.airportid = delays.airportid and
    airports.city = 'Albuquerque' and
    delays.day = day.day), 0) as delay
from day
order by delay, day.day
;

-- 10 --
with num_cities(num_cities) as (
    select count(distinct airports.city) from
    airports 
    where 
    airports.state = 'New York'
),
cities(city) as (
    select airports.city from
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
select temp.city as name from
    (select cities.city, coalesce(
        (
            select num_cities from num_cities_covered 
            where num_cities_covered.city = cities.city
        ), 0
    ) as num_cities from 
    cities
    ) temp, num_cities
where temp.num_cities = num_cities.num_cities - 1
order by temp.city
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
        edge_authors where 
        author1 = 1235
    union 
        select paths.author1, edge_authors.author2, paths.paths || array[edge_authors.author2] 
        from edge_authors, paths
        where edge_authors.author1 = paths.author2 and
        edge_authors.author2 != all(paths.paths)
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
            where author2 = 2826
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
    end) as count
from connected_components as a1, connected_components as a2
where a1.authorid = 1558 and
a2.authorid = 2826
;

-- 14 --
with num_paths(author1, author2, count) as ( 
    with recursive paths(author1, author2, paths, cited) as (
            select author1, author2, array[author1, author2], false
            from edge_authors
            where author2 = 102
        union 
            select edge_authors.author1, paths.author2, 
            array[edge_authors.author1] || paths.paths,
            paths.cited or 
            (
            select count(*) from papers_cited as p1
            where p1.authorid = paths.paths[1] and
            p1.papers_cited = 126
            ) >= 1 

            from edge_authors, paths, papers_cited as p1
            where edge_authors.author2 = paths.author1 and
            edge_authors.author1 != all(paths.paths)
    )
    select author1, author2, count(*) 
    from paths
    where paths.cited or
    array_length(paths.paths, 1) = 2
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
    end) as count
from connected_components as a1, connected_components as a2
where a1.authorid = 704 and
a2.authorid = 102
;

-- 15 --
with num_paths(author1, author2, count) as (
    with recursive paths(author1, author2, paths, increasing, decreasing, last_count) as (
        with num_citations_temp(authorid, count) as (
            select authorid, count(*) from
            author_citation
            group by authorid
        ), 
        num_citations(authorid, count) as (
            select a1.authorid, coalesce(
                (select num_citations_temp.count from num_citations_temp
                where a1.authorid = num_citations_temp.authorid)
                , 0
            ) from authordetails as a1
        )
            select author1, author2, array[author1, author2], true, true, cast(-1 as bigint)
            from edge_authors where
            author2 = 456
        union 
            select edge_authors.author1, paths.author2, 
            array[edge_authors.author1] || paths.paths,
            paths.increasing and (array_length(paths.paths, 1) = 2 or n1.count < last_count),
            paths.decreasing and (array_length(paths.paths, 1) = 2 or n1.count > last_count),
            n1.count
            from edge_authors, paths, num_citations as n1
            where edge_authors.author2 = paths.author1 and
            edge_authors.author1 != all(paths.paths) and
            n1.authorid = paths.paths[1] and
            (paths.decreasing or paths.increasing)
    )
    select author1, author2, count(*) 
    from paths
    where paths.increasing or
    paths.decreasing
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
    end) as count
from connected_components as a1, connected_components as a2
where a1.authorid = 1745 and
a2.authorid = 456
;

-- 16 --
with author_cited(author1, author2) as (
    select distinct papers_cited.authorid, authorpaperlist.authorid from
    authorpaperlist, papers_cited
    where authorpaperlist.paperid = papers_cited.papers_cited and
    papers_cited.authorid != authorpaperlist.authorid
),
future_contributions(authorid, num, rank) as (
    select author_cited.author1, count(*),
    rank() over (order by count(*) desc, author_cited.author1)
    from author_cited
    where (
        select count(*) from edge_authors
        where edge_authors.author1 = author_cited.author1 and
        edge_authors.author2 = author_cited.author2
    ) = 0 
    group by author_cited.author1
)
select authorid from future_contributions
where rank <= 10
order by rank
;

-- 17 --
with third_degree_connections(author1, author2) as (
    with recursive paths(author1, author2, paths) as (
        select author1, author2, array[author1, author2] from
        edge_authors
    union 
        select edge_authors.author1, paths.author2, array[edge_authors.author1] || paths.paths
        from edge_authors, paths
        where edge_authors.author2 = paths.author1 and
        edge_authors.author1 != all(paths.paths) and
        array_length(paths.paths, 1) <= 4
    ), 
    shortest_path(author1, author2, length) as (
        select author1, author2, min(array_length(paths, 1) - 1)
        from paths
        group by author1, author2
    )
    select author1, author2 from
    shortest_path
    where shortest_path.length = 3
),
citations(paperid, count) as (
    with recursive reachable(paper1, paper2) as (
            select paperid1, paperid2 from 
            citationlist
        union
            select citationlist.paperid1, reachable.paper2 from
            reachable, citationlist
            where citationlist.paperid2 = reachable.paper1
    )
    select paper2, count(*) from
    reachable
    group by paper2
)
select authorid from (
    select third_degree_connections.author1 as authorid, sum(citations.count), 
    rank() over (order by sum(citations.count) desc, third_degree_connections.author1)
    from third_degree_connections, citations, authorpaperlist as a1
    where 
    a1.authorid = third_degree_connections.author2 and
    a1.paperid = citations.paperid
    group by third_degree_connections.author1
) temp
where rank <= 10
order by rank
;

-- 18 --
with num_paths(author1, author2, count) as (
    with recursive paths(author1, author2, paths, contains) as (
        select author1, author2, array[author1, author2], false
        from edge_authors where
        author2 = 321
    union 
        select edge_authors.author1, paths.author2, 
        array[edge_authors.author1] || paths.paths,
        paths.contains or paths.paths[1] in (1436, 562, 921)

        from edge_authors, paths
        where edge_authors.author2 = paths.author1 and
        edge_authors.author1 != all(paths.paths)
    )
    select author1, author2, count(*)
    from paths
    where paths.contains
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
    end) as count
from connected_components as a1, connected_components as a2
where a1.authorid = 3552 and
a2.authorid = 321
;

-- 19 --
with num_paths(author1, author2, count) as (
    with recursive paths(author1, author2, paths, cities) as (
        with direct_citations(author1, author2) as (
                select distinct a1.authorid, a2.authorid from
                authorpaperlist as a1, authorpaperlist as a2,
                citationlist as c1
                where ((c1.paperid1 = a1.paperid and
                c1.paperid2 = a2.paperid) or
                (c1.paperid1 = a2.paperid and c1.paperid2 = a1.paperid)) and
                a1.authorid != a2.authorid
        )
            select author1, author2, array[author1, author2],
            array[a1.city, a2.city]
            from edge_authors, authordetails as a1, authordetails as a2
            where a1.authorid = author1 and
            a2.authorid = author2 and
            author2 = 321
        union 
            select edge_authors.author1, paths.author2, 
            array[edge_authors.author1] || paths.paths,
            array[a1.city] || paths.cities

            from edge_authors, paths, authordetails as a1
            where edge_authors.author2 = paths.author1 and
            edge_authors.author1 != all(paths.paths) and
            a1.authorid = edge_authors.author1 and

            -- Check for different cities
            paths.cities[1] != all(paths.cities[2 : array_length(paths.cities, 1) - 1]) and

            -- Check for direct citations
            (
                select count(*) from 
                direct_citations as d1
                where d1.author1 = paths.paths[1] and
                d1.author2 = any(paths.paths[2 : array_length(paths.paths, 1) - 1])
            ) = 0
    )
    select author1, author2, count(*) 
    from paths
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
    end) as count
from connected_components as a1, connected_components as a2
where a1.authorid = 3552 and
a2.authorid = 321
;

-- 20 --
with num_paths(author1, author2, count) as (
    with recursive paths(author1, author2, paths) as (
        with author_cited(author1, author2) as (
            select distinct papers_cited.authorid, authorpaperlist.authorid from
            authorpaperlist, papers_cited
            where authorpaperlist.paperid = papers_cited.papers_cited and
            papers_cited.authorid != authorpaperlist.authorid
        )
            select author1, author2, array[author1, author2]
            from edge_authors where 
            author2 = 321
        union 
            select edge_authors.author1, paths.author2, 
            array[edge_authors.author1] || paths.paths

            from edge_authors, paths
            where edge_authors.author2 = paths.author1 and
            edge_authors.author1 != all(paths.paths) and

            -- Check for citations
            (
                select count(*) from 
                author_cited as d1
                where (d1.author1 = paths.paths[1] and
                d1.author2 = any(paths.paths[2 : array_length(paths.paths, 1) - 1])) or
                (d1.author2 = paths.paths[1] and
                d1.author1 = any(paths.paths[2 : array_length(paths.paths, 1) - 1]))
            ) = 0
    )
    select author1, author2, count(*) 
    from paths
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
    end) as count
from connected_components as a1, connected_components as a2
where a1.authorid = 3552 and
a2.authorid = 321
;

-- 21 --
with connected_components_conf(conferencename, count) as (
    with reachable_list(authorid, conference, list) as (
        with recursive paths(author1, author2, conference) as (
                select author1, author2, conference
                from edge_authors_conf
            union 
                select edge_authors_conf.author1, paths.author2, 
                paths.conference
                from edge_authors_conf, paths
                where edge_authors_conf.author2 = paths.author1 and
                edge_authors_conf.conference = paths.conference
        )
        select paths.author1, paths.conference,
        array_agg(paths.author2 order by paths.author2) 
        from paths
        group by paths.author1, paths.conference
    )
    select conference, count(*) from (
        select conference, list from
        reachable_list
        group by conference, list
    ) temp
    group by conference
)
select * from connected_components_conf
order by count desc, conferencename
;

-- 22 --
with connected_components_conf(conferencename, count) as (
    with reachable_list(authorid, conference, list) as (
        with recursive paths(author1, author2, conference) as (
                select author1, author2, conference
                from edge_authors_conf
            union 
                select edge_authors_conf.author1, paths.author2, 
                paths.conference
                from edge_authors_conf, paths
                where edge_authors_conf.author2 = paths.author1 and
                edge_authors_conf.conference = paths.conference
        )
        select paths.author1, paths.conference,
        array_agg(paths.author2 order by paths.author2) 
        from paths
        group by paths.author1, paths.conference
    )
    select conference, array_length(temp.list, 1)
    from (
        select conference, list from
        reachable_list
        group by conference, list
    ) temp
)
select * from connected_components_conf
order by count, conferencename
;

-- CLEANUP --
drop view connected_components cascade;
drop view edge_authors cascade;
drop view edge_authors_conf cascade;
drop view papers_cited cascade;
drop view author_citation;