DROP FUNCTION IF EXISTS wh.results_for_territory_parties(
    text,
    integer,
    text,
    bigint
);

CREATE OR REPLACE FUNCTION wh.results_for_territory_parties(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_territory_key bigint
)
RETURNS TABLE (
    political_entity_key bigint,
    sigla text,
    name text,
    entity_type text,
    color text,
    votes bigint,
    vote_pct numeric,
    seats integer,
    seat_pct numeric,
    is_winner boolean
)
LANGUAGE sql
STABLE
AS $$
WITH ctx AS (
    SELECT
        e.election_key,
        e.election_type,
        e.election_year,
        o.office_key,
        o.office_code,
        t.territory_key,
        t.territory_code,
        t.territory_level
    FROM wh.dim_election e
    JOIN wh.dim_office o
      ON lower(o.office_code) = lower(p_office)
    JOIN wh.dim_territory t
      ON t.territory_key = p_territory_key
    WHERE lower(e.election_type) = lower(p_election_type)
      AND e.election_year = p_election_year
    LIMIT 1
),

target_territories AS (
    SELECT DISTINCT
        rt.territory_key
    FROM ctx
    JOIN wh.dim_territory rt
      ON (
            (
                ctx.territory_code = 'PT'
                AND (
                    (upper(ctx.office_code) = 'AR' AND rt.territory_level = 'district')
                    OR (upper(ctx.office_code) IN ('PR', 'PE') AND rt.territory_code = 'PT')
                    OR (upper(ctx.office_code) IN ('CM', 'AM') AND rt.territory_level = 'municipality')
                    OR (upper(ctx.office_code) = 'AF' AND rt.territory_level = 'parish')
                )
            )

            OR

            (
                ctx.territory_level = 'district'
                AND (
                    (upper(ctx.office_code) = 'AR' AND rt.territory_code = ctx.territory_code)

                    OR (
                        upper(ctx.office_code) IN ('CM', 'AM')
                        AND rt.territory_level = 'municipality'
                        AND rt.parent_code = ctx.territory_code
                    )

                    OR (
                        upper(ctx.office_code) = 'AF'
                        AND rt.territory_level = 'parish'
                        AND EXISTS (
                            SELECT 1
                            FROM wh.dim_territory municipality
                            WHERE municipality.territory_code = rt.parent_code
                              AND municipality.parent_code = ctx.territory_code
                        )
                    )
                )
            )

            OR

            (
                ctx.territory_level = 'municipality'
                AND (
                    (upper(ctx.office_code) IN ('CM', 'AM') AND rt.territory_code = ctx.territory_code)

                    OR (
                        upper(ctx.office_code) = 'AF'
                        AND rt.territory_level = 'parish'
                        AND rt.parent_code = ctx.territory_code
                    )
                )
            )

            OR

            (
                ctx.territory_level = 'parish'
                AND rt.territory_code = ctx.territory_code
            )
      )
),

vote_rows AS (
    SELECT
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        ) AS sigla,
        SUM(f.votes)::bigint AS votes
    FROM ctx
    JOIN wh.fact_vote_result f
      ON f.election_key = ctx.election_key
     AND f.office_key = ctx.office_key
    JOIN target_territories tt
      ON tt.territory_key = f.territory_key
    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = f.political_entity_key
    GROUP BY
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        )
),

seat_rows AS (
    SELECT
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        ) AS sigla,
        SUM(f.seats)::integer AS seats
    FROM ctx
    JOIN wh.fact_seat_result f
      ON f.election_key = ctx.election_key
     AND f.office_key = ctx.office_key
    JOIN target_territories tt
      ON tt.territory_key = f.territory_key
    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = f.political_entity_key
    GROUP BY
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        )
),

combined AS (
    SELECT
        COALESCE(v.sigla, s.sigla) AS sigla,
        COALESCE(v.votes, 0)::bigint AS votes,
        COALESCE(s.seats, 0)::integer AS seats
    FROM vote_rows v
    FULL OUTER JOIN seat_rows s
      ON s.sigla = v.sigla
),

totals AS (
    SELECT
        COALESCE(SUM(votes), 0)::numeric AS total_votes,
        COALESCE(SUM(seats), 0)::numeric AS total_seats,
        COALESCE(MAX(votes), 0) AS max_votes
    FROM combined
),

display AS (
    SELECT
        c.sigla,
        c.votes,
        c.seats,
        dpe.political_entity_key,
        COALESCE(dpe.name, c.sigla) AS name,
        COALESCE(dpe.entity_type, op.infer_political_entity_type(c.sigla, NULL)) AS entity_type,
        COALESCE(
            dpe.color,
            CASE
                WHEN op.infer_political_entity_type(c.sigla, NULL) = 'coalition' THEN '#6A8F83'
                WHEN op.infer_political_entity_type(c.sigla, NULL) = 'gce' THEN '#5C7A70'
                ELSE '#4F6B62'
            END
        ) AS color
    FROM combined c
    LEFT JOIN wh.dim_political_entity dpe
      ON dpe.sigla = c.sigla
)

SELECT
    display.political_entity_key,
    display.sigla,
    display.name,
    display.entity_type,
    display.color,
    display.votes,
    CASE
        WHEN totals.total_votes > 0
        THEN round(display.votes::numeric * 100 / totals.total_votes, 2)
        ELSE 0
    END AS vote_pct,
    display.seats,
    CASE
        WHEN totals.total_seats > 0
        THEN round(display.seats::numeric * 100 / totals.total_seats, 2)
        ELSE 0
    END AS seat_pct,
    display.votes = totals.max_votes AS is_winner
FROM display
CROSS JOIN totals
WHERE display.votes > 0
   OR display.seats > 0
ORDER BY
    wh.political_entity_order(display.sigla) ASC,
    display.seats DESC,
    display.votes DESC,
    display.sigla ASC;
$$;
