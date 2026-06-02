DROP FUNCTION IF EXISTS wh.rise_and_fall(text, text, text, text, text, text);
DROP FUNCTION IF EXISTS wh.rise_and_fall(text, text, text, text, text);
DROP FUNCTION IF EXISTS wh.rise_and_fall(text, text, bigint, text, text);

CREATE OR REPLACE FUNCTION wh.rise_and_fall(
    p_election_type text,
    p_office text,
    p_territory_key bigint,
    p_metric text DEFAULT 'votes',
    p_direction text DEFAULT 'rise'
)
RETURNS TABLE (
    election_year integer,
    sigla text,
    name text,
    color text,
    value numeric,
    votes bigint,
    seats integer,
    variation_value numeric,
    proportional_variation numeric,
    variation_direction text
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
        FROM wh.fact_vote_result f
        JOIN wh.dim_election e
          ON e.election_key = f.election_key
        JOIN wh.dim_office o
          ON o.office_key = f.office_key
        JOIN root_territory rt
          ON rt.territory_key = f.territory_key
        WHERE e.election_type = p_election_type
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

base AS (
    SELECT
        e.election_year,
        pe.political_entity_key,
        pe.sigla,
        pe.name,
        pe.color,

        SUM(COALESCE(f.votes, 0))::bigint AS votes,
        SUM(COALESCE(sr.seats, 0))::integer AS seats
    FROM wh.fact_vote_result f
    JOIN wh.dim_election e
      ON e.election_key = f.election_key
    JOIN wh.dim_office o
      ON o.office_key = f.office_key
    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = f.political_entity_key
     AND pe.entity_type = 'party'
    JOIN source_territories st
      ON st.territory_key = f.territory_key
    LEFT JOIN wh.fact_seat_result sr
      ON sr.election_key = f.election_key
     AND sr.office_key = f.office_key
     AND sr.territory_key = f.territory_key
     AND sr.political_entity_key = f.political_entity_key
    WHERE e.election_type = p_election_type
      AND o.office_code = p_office
      AND p_metric IN ('votes', 'seats')
      AND p_direction IN ('rise', 'fall')
    GROUP BY
        e.election_year,
        pe.political_entity_key,
        pe.sigla,
        pe.name,
        pe.color
),

values_by_year AS (
    SELECT
        b.*,
        CASE
            WHEN p_metric = 'seats'
            THEN b.seats::numeric
            ELSE b.votes::numeric
        END AS metric_value
    FROM base b
),

ranked AS (
    SELECT
        v.*,

        row_number() OVER (
            PARTITION BY v.political_entity_key
            ORDER BY v.election_year ASC
        ) AS rn_first,

        row_number() OVER (
            PARTITION BY v.political_entity_key
            ORDER BY v.election_year DESC
        ) AS rn_last
    FROM values_by_year v
),

firsts AS (
    SELECT
        political_entity_key,
        metric_value AS first_value
    FROM ranked
    WHERE rn_first = 1
),

lasts AS (
    SELECT
        political_entity_key,
        metric_value AS last_value
    FROM ranked
    WHERE rn_last = 1
),

variation AS (
    SELECT
        l.political_entity_key,

        f.first_value,
        l.last_value,

        CASE
            WHEN p_direction = 'rise'
            THEN (l.last_value - f.first_value)::numeric
            ELSE (f.first_value - l.last_value)::numeric
        END AS variation_value,

        CASE
            WHEN p_direction = 'rise'
             AND f.first_value > 0
            THEN ((l.last_value - f.first_value) / f.first_value)::numeric

            WHEN p_direction = 'fall'
             AND f.first_value > 0
            THEN ((f.first_value - l.last_value) / f.first_value)::numeric

            ELSE NULL
        END AS proportional_variation,

        CASE
            WHEN p_direction = 'rise'
             AND f.first_value > 0
             AND l.last_value > 0
            THEN ((l.last_value - f.first_value) / f.first_value) * sqrt(l.last_value)

            WHEN p_direction = 'fall'
             AND f.first_value > 0
             AND l.last_value >= 0
            THEN ((f.first_value - l.last_value) / f.first_value) * sqrt(f.first_value)

            ELSE NULL
        END AS variation_score
    FROM lasts l
    JOIN firsts f
      ON f.political_entity_key = l.political_entity_key
),

top_parties AS (
    SELECT
        v.political_entity_key,
        v.variation_value,
        v.proportional_variation,
        v.variation_score
    FROM variation v
    WHERE v.variation_value > 0
      AND v.proportional_variation IS NOT NULL
      AND v.variation_score IS NOT NULL
    ORDER BY
        v.variation_score DESC,
        v.variation_value DESC
    LIMIT 4
),

selected_rows AS (
    SELECT
        v.election_year,
        v.sigla::text AS sigla,
        v.name::text AS name,
        v.color::text AS color,
        v.metric_value AS value,
        v.votes,
        v.seats,
        tp.variation_value,
        tp.proportional_variation,
        tp.variation_score,
        p_direction::text AS variation_direction
    FROM values_by_year v
    JOIN top_parties tp
      ON tp.political_entity_key = v.political_entity_key
)

SELECT
    sr.election_year,
    sr.sigla,
    sr.name,
    sr.color,
    sr.value,
    sr.votes,
    sr.seats,
    sr.variation_value,
    sr.proportional_variation,
    sr.variation_direction
FROM selected_rows sr
ORDER BY
    sr.election_year ASC,
    sr.variation_score DESC,
    sr.sigla ASC;
$$;
