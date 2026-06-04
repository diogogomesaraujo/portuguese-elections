CREATE OR REPLACE FUNCTION wh.get_turnout_rollup(
    p_election_key bigint,
    p_office_key   bigint DEFAULT NULL
)
RETURNS TABLE (
    territory_level  text,
    territory_code   text,
    territory_name   text,
    parent_code      text,
    parent_name      text,
    registered_voters bigint,
    voters            bigint,
    blank_votes       bigint,
    null_votes        bigint,
    candidate_votes   bigint,
    turnout_rate      numeric,
    blank_rate        numeric,
    null_rate         numeric
)
LANGUAGE sql
STABLE
AS $$
SELECT
    COALESCE(dt.territory_level, 'national')        AS territory_level,
    dt.territory_code,
    dt.territory_name,
    dt.parent_code,
    dt.parent_name,

    SUM(ft.registered_voters)::bigint               AS registered_voters,
    SUM(ft.voters)::bigint                          AS voters,
    SUM(ft.blank_votes)::bigint                     AS blank_votes,
    SUM(ft.null_votes)::bigint                      AS null_votes,
    SUM(ft.candidate_votes)::bigint                 AS candidate_votes,

    CASE
        WHEN SUM(ft.registered_voters) > 0
            THEN ROUND(SUM(ft.voters)::numeric
                     / SUM(ft.registered_voters), 6)
        END                                             AS turnout_rate,

    CASE
        WHEN SUM(ft.voters) > 0
            THEN ROUND(SUM(ft.blank_votes)::numeric
                     / SUM(ft.voters), 6)
        END                                             AS blank_rate,

    CASE
        WHEN SUM(ft.voters) > 0
            THEN ROUND(SUM(ft.null_votes)::numeric
                     / SUM(ft.voters), 6)
        END                                             AS null_rate

FROM wh.fact_turnout ft
         JOIN wh.dim_territory dt
              ON dt.territory_key = ft.territory_key

WHERE ft.election_key = p_election_key
  AND (p_office_key IS NULL OR ft.office_key = p_office_key)

GROUP BY ROLLUP (
    (dt.territory_level, dt.parent_code, dt.parent_name,
     dt.territory_code, dt.territory_name)
    )

ORDER BY
    territory_level NULLS LAST,
    parent_code,
    territory_code
    $$;