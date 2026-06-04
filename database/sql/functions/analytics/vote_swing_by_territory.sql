DROP FUNCTION IF EXISTS wh.vote_swing_by_territory(text, text, integer, integer);

CREATE OR REPLACE FUNCTION wh.vote_swing_by_territory(
    p_election_type text,
    p_office text,
    p_from_year integer,
    p_to_year integer
)
RETURNS TABLE (
    territory_key bigint,
    territory_code text,
    territory_name text,
    territory_level text,

    from_year integer,
    to_year integer,

    from_total_votes bigint,
    to_total_votes bigint,

    from_left_votes bigint,
    from_right_votes bigint,
    from_other_votes bigint,

    to_left_votes bigint,
    to_right_votes bigint,
    to_other_votes bigint,

    from_left_share numeric,
    from_right_share numeric,
    from_margin numeric,

    to_left_share numeric,
    to_right_share numeric,
    to_margin numeric,

    swing_value numeric,
    swing_direction text
)
LANGUAGE sql
STABLE
AS $$
WITH RECURSIVE raw AS (
    SELECT
        e.election_year,
        f.territory_key,
        wh.get_political_side(f.political_entity_key) AS political_side,
        SUM(COALESCE(f.votes, 0))::bigint AS votes
    FROM wh.fact_vote_result f
    JOIN wh.dim_election e
      ON e.election_key = f.election_key
    JOIN wh.dim_office o
      ON o.office_key = f.office_key
    WHERE e.election_type = p_election_type
      AND e.election_year IN (p_from_year, p_to_year)
      AND o.office_code = p_office
    GROUP BY
        e.election_year,
        f.territory_key,
        wh.get_political_side(f.political_entity_key)
),

classified AS (
    SELECT
        r.election_year,
        r.territory_key,
        CASE
            WHEN r.political_side = 'left' THEN 'left'
            WHEN r.political_side = 'right' THEN 'right'
            ELSE 'other'
        END AS bloc,
        r.votes
    FROM raw r
),

territory_closure AS (
    SELECT
        t.territory_key AS source_territory_key,
        t.territory_key AS rollup_territory_key
    FROM wh.dim_territory t

    UNION ALL

    SELECT
        tc.source_territory_key,
        parent.territory_key AS rollup_territory_key
    FROM territory_closure tc
    JOIN wh.dim_territory current_t
      ON current_t.territory_key = tc.rollup_territory_key
    JOIN wh.dim_territory parent
      ON parent.territory_code = current_t.parent_code
),

rolled AS (
    SELECT
        rt.territory_key,
        rt.territory_code,
        rt.territory_name,
        rt.territory_level,
        c.election_year,

        SUM(c.votes)::bigint AS total_votes,
        COALESCE(SUM(c.votes) FILTER (WHERE c.bloc = 'left'), 0)::bigint AS left_votes,
        COALESCE(SUM(c.votes) FILTER (WHERE c.bloc = 'right'), 0)::bigint AS right_votes,
        COALESCE(SUM(c.votes) FILTER (WHERE c.bloc = 'other'), 0)::bigint AS other_votes
    FROM classified c
    JOIN territory_closure tc
      ON tc.source_territory_key = c.territory_key
    JOIN wh.dim_territory rt
      ON rt.territory_key = tc.rollup_territory_key
    GROUP BY
        rt.territory_key,
        rt.territory_code,
        rt.territory_name,
        rt.territory_level,
        c.election_year
),

shares AS (
    SELECT
        r.*,

        CASE
            WHEN r.total_votes > 0
            THEN r.left_votes::numeric / r.total_votes::numeric
            ELSE NULL
        END AS left_share,

        CASE
            WHEN r.total_votes > 0
            THEN r.right_votes::numeric / r.total_votes::numeric
            ELSE NULL
        END AS right_share,

        CASE
            WHEN r.total_votes > 0
            THEN (r.right_votes::numeric - r.left_votes::numeric) / r.total_votes::numeric
            ELSE NULL
        END AS margin
    FROM rolled r
),

from_y AS (
    SELECT *
    FROM shares
    WHERE election_year = p_from_year
),

to_y AS (
    SELECT *
    FROM shares
    WHERE election_year = p_to_year
),

paired AS (
    SELECT
        COALESCE(t.territory_key, f.territory_key) AS territory_key,
        COALESCE(t.territory_code, f.territory_code) AS territory_code,
        COALESCE(t.territory_name, f.territory_name) AS territory_name,
        COALESCE(t.territory_level, f.territory_level) AS territory_level,

        p_from_year AS from_year,
        p_to_year AS to_year,

        COALESCE(f.total_votes, 0)::bigint AS from_total_votes,
        COALESCE(t.total_votes, 0)::bigint AS to_total_votes,

        COALESCE(f.left_votes, 0)::bigint AS from_left_votes,
        COALESCE(f.right_votes, 0)::bigint AS from_right_votes,
        COALESCE(f.other_votes, 0)::bigint AS from_other_votes,

        COALESCE(t.left_votes, 0)::bigint AS to_left_votes,
        COALESCE(t.right_votes, 0)::bigint AS to_right_votes,
        COALESCE(t.other_votes, 0)::bigint AS to_other_votes,

        f.left_share AS from_left_share,
        f.right_share AS from_right_share,
        f.margin AS from_margin,

        t.left_share AS to_left_share,
        t.right_share AS to_right_share,
        t.margin AS to_margin,

        CASE
            WHEN f.margin IS NOT NULL
             AND t.margin IS NOT NULL
            THEN t.margin - f.margin
            ELSE NULL
        END AS swing_value
    FROM from_y f
    FULL JOIN to_y t
      ON t.territory_key = f.territory_key
)

SELECT
    p.territory_key,
    p.territory_code,
    p.territory_name,
    p.territory_level,

    p.from_year,
    p.to_year,

    p.from_total_votes,
    p.to_total_votes,

    p.from_left_votes,
    p.from_right_votes,
    p.from_other_votes,

    p.to_left_votes,
    p.to_right_votes,
    p.to_other_votes,

    p.from_left_share,
    p.from_right_share,
    p.from_margin,

    p.to_left_share,
    p.to_right_share,
    p.to_margin,

    p.swing_value,

    CASE
        WHEN p.swing_value IS NULL THEN 'unknown'
        WHEN p.swing_value > 0 THEN 'right'
        WHEN p.swing_value < 0 THEN 'left'
        ELSE 'stable'
    END AS swing_direction
FROM paired p
ORDER BY
    CASE p.territory_level
        WHEN 'country' THEN 1
        WHEN 'district' THEN 2
        WHEN 'municipality' THEN 3
        WHEN 'parish' THEN 4
        ELSE 9
    END,
    p.territory_code;
$$;

/*
SELECT
    territory_code,
    territory_name,
    territory_level,
    ROUND(from_left_share * 100, 2) AS from_left_pct,
    ROUND(from_right_share * 100, 2) AS from_right_pct,
    ROUND(to_left_share * 100, 2) AS to_left_pct,
    ROUND(to_right_share * 100, 2) AS to_right_pct,
    ROUND(swing_value * 100, 2) AS swing_points,
    swing_direction
FROM wh.vote_swing_by_territory(
    'AUTARQUICAS',
    'AF',
    2021,
    2025
)
ORDER BY ABS(swing_value) DESC NULLS LAST;
*/
