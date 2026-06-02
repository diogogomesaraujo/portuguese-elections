DROP FUNCTION IF EXISTS wh.rise_and_fall(text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION wh.rise_and_fall(
    p_election_type text,
    p_office text,
    p_territory_code text,
    p_territory_level text,
    p_metric text DEFAULT 'votes',
    p_direction text DEFAULT 'growth'
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
    WHERE t.territory_code = p_territory_code
      AND t.territory_level = p_territory_level
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
      AND p_direction IN ('growth', 'fall')
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

        CASE
            WHEN p_direction = 'growth'
            THEN (l.last_value - f.first_value)::numeric
            ELSE (f.first_value - l.last_value)::numeric
        END AS variation_value
    FROM lasts l
    JOIN firsts f
      ON f.political_entity_key = l.political_entity_key
),

top_parties AS (
    SELECT
        v.political_entity_key,
        v.variation_value
    FROM variation v
    WHERE v.variation_value > 0
    ORDER BY v.variation_value DESC
    LIMIT 4
)

SELECT
    v.election_year,
    v.sigla::text,
    v.name::text,
    v.color::text,
    v.metric_value AS value,
    v.votes,
    v.seats,
    tp.variation_value,
    p_direction::text AS variation_direction
FROM values_by_year v
JOIN top_parties tp
  ON tp.political_entity_key = v.political_entity_key
ORDER BY
    v.election_year ASC,
    tp.variation_value DESC,
    v.sigla ASC;
$$;
