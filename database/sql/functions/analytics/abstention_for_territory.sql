DROP FUNCTION IF EXISTS wh.abstention_for_territory(text, integer, text, bigint);

CREATE OR REPLACE FUNCTION wh.abstention_for_territory(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_territory_key bigint
)
RETURNS TABLE (
    territory_key bigint,
    territory_code text,
    territory_name text,
    territory_level text,

    election_year integer,

    registered_voters bigint,
    voters bigint,
    abstentions bigint,

    turnout_rate numeric,
    abstention_rate numeric,

    blank_votes bigint,
    null_votes bigint,
    candidate_votes bigint
)
LANGUAGE sql
STABLE
AS $$
WITH RECURSIVE root_territory AS (
    SELECT
        t.territory_key,
        t.territory_code,
        t.territory_name,
        t.territory_level
    FROM wh.dim_territory t
    WHERE t.territory_key = p_territory_key
    LIMIT 1
),

territory_tree AS (
    SELECT
        rt.territory_key,
        rt.territory_code,
        rt.territory_name,
        rt.territory_level,
        0 AS depth
    FROM root_territory rt

    UNION ALL

    SELECT
        child.territory_key,
        child.territory_code,
        child.territory_name,
        child.territory_level,
        tt.depth + 1 AS depth
    FROM wh.dim_territory child
    JOIN territory_tree tt
      ON child.parent_code = tt.territory_code
),

exact_rows_exist AS (
    SELECT EXISTS (
        SELECT 1
        FROM wh.fact_turnout ft
        JOIN wh.dim_election e
          ON e.election_key = ft.election_key
        JOIN wh.dim_office o
          ON o.office_key = ft.office_key
        JOIN root_territory rt
          ON rt.territory_key = ft.territory_key
        WHERE e.election_type = p_election_type
          AND e.election_year = p_election_year
          AND o.office_code = p_office
    ) AS exists_exact
),

source_territories AS (
    SELECT tt.territory_key
    FROM territory_tree tt
    CROSS JOIN exact_rows_exist ex
    WHERE
        (
            ex.exists_exact = true
            AND tt.depth = 0
        )
        OR
        (
            ex.exists_exact = false
            AND tt.depth > 0
        )
),

aggregated AS (
    SELECT
        SUM(COALESCE(ft.registered_voters, 0))::bigint AS registered_voters,
        SUM(COALESCE(ft.voters, 0))::bigint AS voters,
        SUM(COALESCE(ft.blank_votes, 0))::bigint AS blank_votes,
        SUM(COALESCE(ft.null_votes, 0))::bigint AS null_votes,
        SUM(COALESCE(ft.candidate_votes, 0))::bigint AS candidate_votes
    FROM wh.fact_turnout ft
    JOIN wh.dim_election e
      ON e.election_key = ft.election_key
    JOIN wh.dim_office o
      ON o.office_key = ft.office_key
    JOIN source_territories st
      ON st.territory_key = ft.territory_key
    WHERE e.election_type = p_election_type
      AND e.election_year = p_election_year
      AND o.office_code = p_office
)

SELECT
    rt.territory_key,
    rt.territory_code::text,
    rt.territory_name::text,
    rt.territory_level::text,

    p_election_year AS election_year,

    COALESCE(a.registered_voters, 0)::bigint AS registered_voters,
    COALESCE(a.voters, 0)::bigint AS voters,

    GREATEST(
        COALESCE(a.registered_voters, 0) - COALESCE(a.voters, 0),
        0
    )::bigint AS abstentions,

    CASE
        WHEN COALESCE(a.registered_voters, 0) > 0
        THEN COALESCE(a.voters, 0)::numeric / a.registered_voters::numeric
        ELSE NULL
    END AS turnout_rate,

    CASE
        WHEN COALESCE(a.registered_voters, 0) > 0
        THEN
            (
                COALESCE(a.registered_voters, 0)::numeric
                - COALESCE(a.voters, 0)::numeric
            ) / a.registered_voters::numeric
        ELSE NULL
    END AS abstention_rate,

    COALESCE(a.blank_votes, 0)::bigint AS blank_votes,
    COALESCE(a.null_votes, 0)::bigint AS null_votes,
    COALESCE(a.candidate_votes, 0)::bigint AS candidate_votes
FROM root_territory rt
CROSS JOIN aggregated a;
$$;
