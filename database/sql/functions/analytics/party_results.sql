DROP FUNCTION IF EXISTS wh.party_results(text, integer, text, bigint);

CREATE OR REPLACE FUNCTION wh.party_results(
    p_election_type text,
    p_election_year integer DEFAULT NULL,
    p_office text DEFAULT NULL,
    p_territory_key bigint DEFAULT NULL
)
RETURNS TABLE (
    election_key bigint,
    election_type text,
    election_year integer,
    office_key bigint,
    office_code text,
    territory_key bigint,
    territory_level text,

    political_entity_key bigint,
    sigla text,
    name text,
    entity_type text,
    color text,

    votes bigint,
    vote_pct numeric,

    seats integer,
    seat_pct numeric,

    calculated_seats integer,
    calculated_seat_pct numeric,

    official_seats integer,
    official_seat_pct numeric,

    seat_diff integer,

    is_winner boolean
)
LANGUAGE sql
STABLE
AS $$
WITH selected AS (
    SELECT
        e.election_key,
        e.election_type,
        e.election_year,
        o.office_key,
        o.office_code
    FROM wh.dim_election e
    JOIN wh.dim_office o
      ON (
            p_office IS NULL
            OR lower(o.office_code) = lower(p_office)
            OR lower(o.office_name) = lower(p_office)
         )
    WHERE lower(e.election_type) = lower(p_election_type)
      AND (
            p_election_year IS NULL
            OR e.election_year = p_election_year
          )
),

target AS (
    SELECT
        t.territory_key,
        t.territory_code,
        t.territory_level,
        t.parent_code,
        parent.territory_code AS parent_territory_code,
        parent.territory_level AS parent_territory_level,
        grandparent.territory_code AS grandparent_territory_code,
        grandparent.territory_level AS grandparent_territory_level
    FROM wh.dim_territory t
    LEFT JOIN wh.dim_territory parent
      ON parent.territory_code = t.parent_code
    LEFT JOIN wh.dim_territory grandparent
      ON grandparent.territory_code = parent.parent_code
    WHERE t.territory_key = p_territory_key
    LIMIT 1
),

exact_rows_exist AS (
    SELECT EXISTS (
        SELECT 1
        FROM selected s
        JOIN target tg ON true
        JOIN wh.fact_vote_result fvr
          ON fvr.election_key = s.election_key
         AND fvr.office_key = s.office_key
         AND fvr.territory_key = tg.territory_key
    ) AS exists_exact
),

vote_territories AS (
    SELECT
        s.election_key,
        s.office_key,
        tg.territory_key
    FROM selected s
    JOIN target tg ON true
    CROSS JOIN exact_rows_exist ex
    WHERE ex.exists_exact = true

    UNION ALL

    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN target tg ON true
    CROSS JOIN exact_rows_exist ex
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'district'
     AND (
            tg.territory_level = 'country'
            OR (
                tg.territory_level = 'district'
                AND vt.territory_code =
                    CASE
                        WHEN tg.territory_code IN ('31', '32') THEN '20'
                        WHEN tg.territory_code IN ('41', '42', '43', '44', '45', '46', '47', '48', '49') THEN '19'
                        ELSE tg.territory_code
                    END
            )
            OR (
                tg.territory_level = 'municipality'
                AND vt.territory_code =
                    CASE
                        WHEN tg.parent_code IN ('31', '32') THEN '20'
                        WHEN tg.parent_code IN ('41', '42', '43', '44', '45', '46', '47', '48', '49') THEN '19'
                        ELSE tg.parent_code
                    END
            )
            OR (
                tg.territory_level = 'parish'
                AND vt.territory_code =
                    CASE
                        WHEN tg.grandparent_territory_code IN ('31', '32') THEN '20'
                        WHEN tg.grandparent_territory_code IN ('41', '42', '43', '44', '45', '46', '47', '48', '49') THEN '19'
                        ELSE tg.grandparent_territory_code
                    END
            )
         )
    WHERE ex.exists_exact = false
      AND (
            lower(s.election_type) = 'legislativas'
            OR upper(s.office_code) = 'AR'
          )

    UNION ALL

    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN target tg ON true
    CROSS JOIN exact_rows_exist ex
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'municipality'
     AND (
            tg.territory_level = 'country'
            OR (
                tg.territory_level = 'district'
                AND vt.parent_code = tg.territory_code
            )
            OR (
                tg.territory_level = 'municipality'
                AND vt.territory_code = tg.territory_code
            )
            OR (
                tg.territory_level = 'parish'
                AND vt.territory_code = tg.parent_code
            )
         )
    WHERE ex.exists_exact = false
      AND upper(s.office_code) IN ('CM', 'AM')

    UNION ALL

    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN target tg ON true
    CROSS JOIN exact_rows_exist ex
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'parish'
    LEFT JOIN wh.dim_territory parent_municipality
      ON parent_municipality.territory_code = vt.parent_code
     AND parent_municipality.territory_level = 'municipality'
    WHERE ex.exists_exact = false
      AND upper(s.office_code) = 'AF'
      AND (
            tg.territory_level = 'country'
            OR (
                tg.territory_level = 'district'
                AND parent_municipality.parent_code = tg.territory_code
            )
            OR (
                tg.territory_level = 'municipality'
                AND vt.parent_code = tg.territory_code
            )
            OR (
                tg.territory_level = 'parish'
                AND vt.territory_code = tg.territory_code
            )
          )

    UNION ALL

    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    CROSS JOIN exact_rows_exist ex
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'country'
     AND vt.territory_code = 'PT'
    WHERE ex.exists_exact = false
      AND upper(s.office_code) IN ('PR', 'PE')
),

calculated_seat_result AS (
    SELECT
        election_key,
        office_key,
        territory_key,
        political_entity_key,
        SUM(seats)::integer AS seats
    FROM wh.fact_seat_result
    WHERE lower(COALESCE(method, 'dhondt_calculated')) = 'dhondt_calculated'
    GROUP BY
        election_key,
        office_key,
        territory_key,
        political_entity_key
),

official_seat_result AS (
    SELECT
        election_key,
        office_key,
        territory_key,
        political_entity_key,
        SUM(seats)::integer AS seats
    FROM wh.fact_seat_result
    WHERE lower(method) = 'official'
    GROUP BY
        election_key,
        office_key,
        territory_key,
        political_entity_key
),

raw_totals AS (
    SELECT
        s.election_key,
        s.election_type,
        s.election_year,
        s.office_key,
        s.office_code,

        tg.territory_key,
        tg.territory_level,

        wh.canonical_political_entity_sigla(
            s.election_type,
            s.election_year,
            s.office_code,
            pe.sigla
        ) AS canon_sigla,

        SUM(fvr.votes)::bigint AS votes,

        SUM(COALESCE(csr.seats, 0))::integer AS calculated_seats,
        SUM(COALESCE(osr.seats, 0))::integer AS official_seats
    FROM selected s
    JOIN target tg ON true
    JOIN vote_territories vt
      ON vt.election_key = s.election_key
     AND vt.office_key = s.office_key
    JOIN wh.fact_vote_result fvr
      ON fvr.election_key = s.election_key
     AND fvr.office_key = s.office_key
     AND fvr.territory_key = vt.territory_key
    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = fvr.political_entity_key
    LEFT JOIN calculated_seat_result csr
      ON csr.election_key = fvr.election_key
     AND csr.office_key = fvr.office_key
     AND csr.territory_key = fvr.territory_key
     AND csr.political_entity_key = fvr.political_entity_key
    LEFT JOIN official_seat_result osr
      ON osr.election_key = fvr.election_key
     AND osr.office_key = fvr.office_key
     AND osr.territory_key = fvr.territory_key
     AND osr.political_entity_key = fvr.political_entity_key
    GROUP BY
        s.election_key,
        s.election_type,
        s.election_year,
        s.office_key,
        s.office_code,
        tg.territory_key,
        tg.territory_level,
        wh.canonical_political_entity_sigla(
            s.election_type,
            s.election_year,
            s.office_code,
            pe.sigla
        )
),

party_totals AS (
    SELECT
        rt.election_key,
        rt.election_type,
        rt.election_year,
        rt.office_key,
        rt.office_code,

        rt.territory_key,
        rt.territory_level,

        dpe.political_entity_key,
        rt.canon_sigla AS sigla,
        COALESCE(dpe.name, rt.canon_sigla) AS name,
        COALESCE(dpe.entity_type, op.infer_political_entity_type(rt.canon_sigla, NULL)) AS entity_type,
        COALESCE(
            dpe.color,
            CASE
                WHEN op.infer_political_entity_type(rt.canon_sigla, NULL) = 'coalition' THEN '#6A8F83'
                WHEN op.infer_political_entity_type(rt.canon_sigla, NULL) = 'gce' THEN '#5C7A70'
                ELSE '#4F6B62'
            END
        ) AS color,

        SUM(rt.votes)::bigint AS votes,
        SUM(rt.calculated_seats)::integer AS calculated_seats,
        SUM(rt.official_seats)::integer AS official_seats
    FROM raw_totals rt
    LEFT JOIN wh.dim_political_entity dpe
      ON dpe.sigla = rt.canon_sigla
    GROUP BY
        rt.election_key,
        rt.election_type,
        rt.election_year,
        rt.office_key,
        rt.office_code,
        rt.territory_key,
        rt.territory_level,
        dpe.political_entity_key,
        rt.canon_sigla,
        dpe.name,
        dpe.entity_type,
        dpe.color
),

ranked AS (
    SELECT
        pt.*,

        SUM(pt.votes) OVER (
            PARTITION BY pt.election_key, pt.office_key, pt.territory_key
        ) AS total_votes,

        SUM(pt.calculated_seats) OVER (
            PARTITION BY pt.election_key, pt.office_key, pt.territory_key
        ) AS total_calculated_seats,

        SUM(pt.official_seats) OVER (
            PARTITION BY pt.election_key, pt.office_key, pt.territory_key
        ) AS total_official_seats,

        row_number() OVER (
            PARTITION BY pt.election_key, pt.office_key, pt.territory_key
            ORDER BY
                pt.votes DESC,
                pt.calculated_seats DESC,
                pt.sigla ASC
        ) AS rn
    FROM party_totals pt
)

SELECT
    ranked.election_key,
    ranked.election_type::text,
    ranked.election_year,
    ranked.office_key,
    ranked.office_code::text,
    ranked.territory_key,
    ranked.territory_level::text,

    ranked.political_entity_key,
    ranked.sigla::text,
    ranked.name::text,
    ranked.entity_type::text,
    ranked.color::text,

    ranked.votes,
    CASE
        WHEN ranked.total_votes > 0
        THEN round((ranked.votes::numeric / ranked.total_votes::numeric) * 100, 2)
        ELSE 0
    END AS vote_pct,

    ranked.calculated_seats AS seats,
    CASE
        WHEN ranked.total_calculated_seats > 0
        THEN round((ranked.calculated_seats::numeric / ranked.total_calculated_seats::numeric) * 100, 2)
        ELSE 0
    END AS seat_pct,

    ranked.calculated_seats,
    CASE
        WHEN ranked.total_calculated_seats > 0
        THEN round((ranked.calculated_seats::numeric / ranked.total_calculated_seats::numeric) * 100, 2)
        ELSE 0
    END AS calculated_seat_pct,

    ranked.official_seats,
    CASE
        WHEN ranked.total_official_seats > 0
        THEN round((ranked.official_seats::numeric / ranked.total_official_seats::numeric) * 100, 2)
        ELSE 0
    END AS official_seat_pct,

    ranked.calculated_seats - ranked.official_seats AS seat_diff,

    ranked.rn = 1 AS is_winner
FROM ranked;
$$;
