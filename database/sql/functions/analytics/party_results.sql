DROP FUNCTION IF EXISTS wh.party_results(text, integer, text, text, text);

CREATE OR REPLACE FUNCTION wh.party_results(
    p_election_type text,
    p_election_year integer DEFAULT NULL,
    p_office text DEFAULT NULL,
    p_territory_code text DEFAULT NULL,
    p_territory_level text DEFAULT NULL
)
RETURNS TABLE (
    election_key bigint,
    election_type text,
    election_year integer,
    office_key bigint,
    office_code text,
    territory_code text,
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
    WHERE t.territory_code = p_territory_code
      AND t.territory_level = p_territory_level
    LIMIT 1
),

vote_territories AS (
    /*
      Legislative / AR:
      vote territory is district.
    */
    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN target tg ON true
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'district'
     AND vt.territory_code =
        CASE
            WHEN tg.territory_level = 'district'
            THEN tg.territory_code

            WHEN tg.territory_level = 'municipality'
            THEN tg.parent_code

            WHEN tg.territory_level = 'parish'
            THEN tg.grandparent_territory_code

            ELSE tg.territory_code
        END
    WHERE lower(s.election_type) = 'legislativas'
       OR upper(s.office_code) = 'AR'

    UNION ALL

    /*
      CM / AM:
      vote territory is municipality.
    */
    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN target tg ON true
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'municipality'
     AND (
        (
            tg.territory_level = 'district'
            AND vt.parent_code = tg.territory_code
        )
        OR
        (
            tg.territory_level = 'municipality'
            AND vt.territory_code = tg.territory_code
        )
        OR
        (
            tg.territory_level = 'parish'
            AND vt.territory_code = tg.parent_code
        )
     )
    WHERE upper(s.office_code) IN ('CM', 'AM')

    UNION ALL

    /*
      AF:
      vote territory is parish.
    */
    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN target tg ON true
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'parish'
    LEFT JOIN wh.dim_territory parent_municipality
      ON parent_municipality.territory_code = vt.parent_code
     AND parent_municipality.territory_level = 'municipality'
    WHERE upper(s.office_code) = 'AF'
      AND (
        (
            tg.territory_level = 'district'
            AND parent_municipality.parent_code = tg.territory_code
        )
        OR
        (
            tg.territory_level = 'municipality'
            AND vt.parent_code = tg.territory_code
        )
        OR
        (
            tg.territory_level = 'parish'
            AND vt.territory_code = tg.territory_code
        )
      )

    UNION ALL

    /*
      PR / PE:
      vote territory is country.
    */
    SELECT
        s.election_key,
        s.office_key,
        vt.territory_key
    FROM selected s
    JOIN wh.dim_territory vt
      ON vt.territory_level = 'country'
     AND vt.territory_code = 'PT'
    WHERE upper(s.office_code) IN ('PR', 'PE')
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

party_totals AS (
    SELECT
        s.election_key,
        s.election_type,
        s.election_year,
        s.office_key,
        s.office_code,

        p_territory_code AS territory_code,
        p_territory_level AS territory_level,

        pe.political_entity_key,
        pe.sigla,
        pe.name,
        pe.entity_type,
        pe.color,

        SUM(fvr.votes)::bigint AS votes,

        SUM(COALESCE(csr.seats, 0))::integer AS calculated_seats,
        SUM(COALESCE(osr.seats, 0))::integer AS official_seats
    FROM selected s
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
        pe.political_entity_key,
        pe.sigla,
        pe.name,
        pe.entity_type,
        pe.color
),

ranked AS (
    SELECT
        pt.*,

        SUM(pt.votes) OVER (
            PARTITION BY pt.election_key, pt.office_key
        ) AS total_votes,

        SUM(pt.calculated_seats) OVER (
            PARTITION BY pt.election_key, pt.office_key
        ) AS total_calculated_seats,

        SUM(pt.official_seats) OVER (
            PARTITION BY pt.election_key, pt.office_key
        ) AS total_official_seats,

        row_number() OVER (
            PARTITION BY pt.election_key, pt.office_key
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
    ranked.territory_code::text,
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
