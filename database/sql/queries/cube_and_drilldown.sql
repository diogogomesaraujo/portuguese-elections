DROP FUNCTION IF EXISTS wh.result_cube(
    text,
    integer,
    text,
    text,
    text,
    text
);

CREATE OR REPLACE FUNCTION wh.result_cube(
    p_election_type text DEFAULT NULL,
    p_election_year integer DEFAULT NULL,
    p_office text DEFAULT NULL,
    p_territory_level text DEFAULT NULL,
    p_parent_code text DEFAULT NULL,
    p_entity_type text DEFAULT NULL
)
RETURNS TABLE (
    cube_mask integer,

    election_type text,
    election_year integer,
    office_code text,

    territory_level text,
    parent_code text,
    parent_name text,

    entity_type text,
    sigla text,
    name text,

    territory_count bigint,
    total_votes bigint,
    total_seats bigint,

    avg_vote_share numeric,
    max_vote_share numeric,

    avg_seat_share numeric,
    max_seat_share numeric
)
LANGUAGE sql
STABLE
AS $$
WITH seats AS (
    SELECT
        election_key,
        office_key,
        territory_key,
        political_entity_key,
        SUM(seats) AS seats,
        MAX(seat_share) AS seat_share
    FROM wh.fact_seat_result
    GROUP BY
        election_key,
        office_key,
        territory_key,
        political_entity_key
),

base AS (
    SELECT
        e.election_type,
        e.election_year,
        o.office_code,

        t.territory_key,
        t.territory_level,
        t.parent_code,
        t.parent_name,

        pe.entity_type,
        pe.sigla,
        pe.name,

        vr.votes,
        vr.vote_share,

        COALESCE(s.seats, 0) AS seats,
        s.seat_share
    FROM wh.fact_vote_result vr

    JOIN wh.dim_election e
      ON e.election_key = vr.election_key

    JOIN wh.dim_office o
      ON o.office_key = vr.office_key

    JOIN wh.dim_territory t
      ON t.territory_key = vr.territory_key

    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = vr.political_entity_key

    LEFT JOIN seats s
      ON s.election_key = vr.election_key
     AND s.office_key = vr.office_key
     AND s.territory_key = vr.territory_key
     AND s.political_entity_key = vr.political_entity_key

    WHERE
        (p_election_type IS NULL OR e.election_type = p_election_type)
        AND (p_election_year IS NULL OR e.election_year = p_election_year)
        AND (p_office IS NULL OR o.office_code = p_office)
        AND (p_territory_level IS NULL OR t.territory_level = p_territory_level)
        AND (p_parent_code IS NULL OR t.parent_code = p_parent_code)
        AND (p_entity_type IS NULL OR pe.entity_type = p_entity_type)
)

SELECT
    GROUPING(
        election_type,
        election_year,
        office_code,
        territory_level,
        parent_code,
        parent_name,
        entity_type,
        sigla,
        name
    ) AS cube_mask,

    CASE WHEN GROUPING(election_type) = 1 THEN 'ALL' ELSE election_type END AS election_type,
    CASE WHEN GROUPING(election_year) = 1 THEN NULL ELSE election_year END AS election_year,
    CASE WHEN GROUPING(office_code) = 1 THEN 'ALL' ELSE office_code END AS office_code,

    CASE WHEN GROUPING(territory_level) = 1 THEN 'ALL' ELSE territory_level END AS territory_level,
    CASE WHEN GROUPING(parent_code) = 1 THEN 'ALL' ELSE parent_code END AS parent_code,
    CASE WHEN GROUPING(parent_name) = 1 THEN 'ALL' ELSE parent_name END AS parent_name,

    CASE WHEN GROUPING(entity_type) = 1 THEN 'ALL' ELSE entity_type END AS entity_type,
    CASE WHEN GROUPING(sigla) = 1 THEN 'ALL' ELSE sigla END AS sigla,
    CASE WHEN GROUPING(name) = 1 THEN 'ALL' ELSE name END AS name,

    COUNT(DISTINCT territory_key) AS territory_count,

    SUM(votes)::bigint AS total_votes,
    SUM(seats)::bigint AS total_seats,

    ROUND(AVG(vote_share), 6) AS avg_vote_share,
    ROUND(MAX(vote_share), 6) AS max_vote_share,

    ROUND(AVG(seat_share), 6) AS avg_seat_share,
    ROUND(MAX(seat_share), 6) AS max_seat_share

FROM base

GROUP BY CUBE (
    election_type,
    election_year,
    office_code,
    territory_level,
    parent_code,
    parent_name,
    entity_type,
    sigla,
    name
)

HAVING SUM(votes) IS NOT NULL

ORDER BY
    cube_mask,
    election_type,
    election_year,
    office_code,
    territory_level,
    parent_code,
    total_votes DESC;
$$;

DROP FUNCTION IF EXISTS wh.result_rollup(
    text,
    integer,
    text,
    text
);

CREATE OR REPLACE FUNCTION wh.result_rollup(
    p_election_type text DEFAULT NULL,
    p_election_year integer DEFAULT NULL,
    p_office text DEFAULT NULL,
    p_territory_code text DEFAULT NULL
)
RETURNS TABLE (
    rollup_mask integer,
    rollup_depth integer,

    election_type text,
    election_year integer,
    office_code text,

    territory_level text,
    parent_code text,
    parent_name text,
    territory_code text,
    territory_name text,

    sigla text,
    name text,
    entity_type text,

    total_votes bigint,
    total_seats bigint,
    territories_count bigint,

    avg_vote_share numeric,
    max_vote_share numeric
)
LANGUAGE sql
STABLE
AS $$
WITH seats AS (
    SELECT
        election_key,
        office_key,
        territory_key,
        political_entity_key,
        SUM(seats) AS seats
    FROM wh.fact_seat_result
    GROUP BY
        election_key,
        office_key,
        territory_key,
        political_entity_key
),

base AS (
    SELECT
        e.election_type,
        e.election_year,
        o.office_code,

        t.territory_key,
        t.territory_level,
        t.parent_code,
        t.parent_name,
        t.territory_code,
        t.territory_name,

        pe.sigla,
        pe.name,
        pe.entity_type,

        vr.votes,
        vr.vote_share,

        COALESCE(s.seats, 0) AS seats
    FROM wh.fact_vote_result vr

    JOIN wh.dim_election e
      ON e.election_key = vr.election_key

    JOIN wh.dim_office o
      ON o.office_key = vr.office_key

    JOIN wh.dim_territory t
      ON t.territory_key = vr.territory_key

    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = vr.political_entity_key

    LEFT JOIN seats s
      ON s.election_key = vr.election_key
     AND s.office_key = vr.office_key
     AND s.territory_key = vr.territory_key
     AND s.political_entity_key = vr.political_entity_key

    WHERE
        (p_election_type IS NULL OR e.election_type = p_election_type)
        AND (p_election_year IS NULL OR e.election_year = p_election_year)
        AND (p_office IS NULL OR o.office_code = p_office)
        AND (p_territory_code IS NULL OR t.territory_code = p_territory_code)
)

SELECT
    GROUPING(
        election_type,
        election_year,
        office_code,
        territory_level,
        parent_code,
        parent_name,
        territory_code,
        territory_name,
        entity_type,
        sigla,
        name
    ) AS rollup_mask,

    11 - (
        GROUPING(election_type)
        + GROUPING(election_year)
        + GROUPING(office_code)
        + GROUPING(territory_level)
        + GROUPING(parent_code)
        + GROUPING(parent_name)
        + GROUPING(territory_code)
        + GROUPING(territory_name)
        + GROUPING(entity_type)
        + GROUPING(sigla)
        + GROUPING(name)
    ) AS rollup_depth,

    CASE WHEN GROUPING(election_type) = 1 THEN 'ALL' ELSE election_type END AS election_type,
    CASE WHEN GROUPING(election_year) = 1 THEN NULL ELSE election_year END AS election_year,
    CASE WHEN GROUPING(office_code) = 1 THEN 'ALL' ELSE office_code END AS office_code,

    CASE WHEN GROUPING(territory_level) = 1 THEN 'ALL' ELSE territory_level END AS territory_level,
    CASE WHEN GROUPING(parent_code) = 1 THEN 'ALL' ELSE parent_code END AS parent_code,
    CASE WHEN GROUPING(parent_name) = 1 THEN 'ALL' ELSE parent_name END AS parent_name,
    CASE WHEN GROUPING(territory_code) = 1 THEN 'ALL' ELSE territory_code END AS territory_code,
    CASE WHEN GROUPING(territory_name) = 1 THEN 'ALL' ELSE territory_name END AS territory_name,

    CASE WHEN GROUPING(sigla) = 1 THEN 'ALL' ELSE sigla END AS sigla,
    CASE WHEN GROUPING(name) = 1 THEN 'ALL' ELSE name END AS name,
    CASE WHEN GROUPING(entity_type) = 1 THEN 'ALL' ELSE entity_type END AS entity_type,

    SUM(votes)::bigint AS total_votes,
    SUM(seats)::bigint AS total_seats,
    COUNT(DISTINCT territory_key) AS territories_count,

    ROUND(AVG(vote_share), 6) AS avg_vote_share,
    ROUND(MAX(vote_share), 6) AS max_vote_share

FROM base

GROUP BY ROLLUP (
    election_type,
    election_year,
    office_code,
    territory_level,
    parent_code,
    parent_name,
    territory_code,
    territory_name,
    entity_type,
    sigla,
    name
)

HAVING SUM(votes) IS NOT NULL

ORDER BY
    election_type,
    election_year,
    office_code,
    territory_level,
    parent_code,
    territory_code,
    total_votes DESC;
$$;

SELECT *
FROM wh.result_cube(
    'LEGISLATIVAS',
    NULL,
    'AR',
    NULL,
    NULL,
    NULL
)
WHERE
    territory_level = 'ALL'
    AND parent_code = 'ALL'
    AND entity_type = 'party'
    AND sigla <> 'ALL'
ORDER BY
    election_year,
    total_votes DESC;


SELECT
    election_year,
    office_code,
    parent_code,
    parent_name,
    sigla,
    total_votes,
    total_seats,
    territory_count,
    avg_vote_share,
    max_vote_share
FROM wh.result_cube(
    'LEGISLATIVAS',
    NULL,
    'AR',
    NULL,
    NULL,
    NULL
)
WHERE
    election_year IS NOT NULL
    AND office_code = 'AR'
    AND territory_level = 'district'
    AND parent_code = 'ALL'
    AND entity_type = 'party'
    AND sigla <> 'ALL'
ORDER BY
    election_year,
    total_votes DESC;

SELECT
    rollup_depth,
    election_type,
    election_year,
    office_code,
    territory_level,
    parent_code,
    parent_name,
    territory_code,
    territory_name,
    entity_type,
    sigla,
    total_votes,
    total_seats,
    territories_count
FROM wh.result_rollup(
    'AUTARQUICAS',
    2021,
    'CM',
    NULL
)
WHERE rollup_depth >= 5
ORDER BY
    rollup_depth,
    parent_code,
    territory_code,
    total_votes DESC
LIMIT 300;

SELECT
    rollup_depth,
    election_type,
    election_year,
    office_code,
    territory_level,
    territory_code,
    territory_name,
    entity_type,
    sigla,
    name,
    total_votes,
    total_seats,
    avg_vote_share,
    max_vote_share
FROM wh.result_rollup(
    'AUTARQUICAS',
    2021,
    'CM',
    '0101'
)
WHERE sigla <> 'ALL'
ORDER BY
    total_votes DESC;
