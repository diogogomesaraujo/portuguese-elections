DROP FUNCTION IF EXISTS wh.party_over_years(text, text, text, text, text);

CREATE OR REPLACE FUNCTION wh.party_over_years(
    p_election_type text,
    p_office text,
    p_territory_code text,
    p_territory_level text,
    p_party_sigla text
)
RETURNS TABLE (
    election_year integer,

    display_sigla text,
    display_name text,
    display_color text,

    result_sigla text,
    result_name text,
    result_color text,

    result_kind text,

    votes bigint,
    vote_pct numeric,

    seats integer,
    seat_pct numeric,

    calculated_seats integer,
    calculated_seat_pct numeric,

    official_seats integer,
    official_seat_pct numeric,

    seat_diff integer,

    is_winner boolean,

    chart_color text
)
LANGUAGE sql
STABLE
AS $$
WITH wanted_party AS (
    SELECT
        pe.political_entity_key,
        pe.sigla,
        pe.name,
        pe.color
    FROM wh.dim_political_entity pe
    WHERE lower(pe.sigla) = lower(p_party_sigla)
    LIMIT 1
),

base_results AS (
    SELECT
        b.*
    FROM wh.party_results(
        p_election_type,
        NULL::integer,
        p_office,
        p_territory_code,
        p_territory_level
    ) b
),

expanded_results AS (
    SELECT
        b.election_year,

        wp.sigla AS display_sigla,
        wp.name AS display_name,
        wp.color AS display_color,

        b.sigla AS result_sigla,
        b.name AS result_name,
        b.color AS result_color,

        CASE
            WHEN b.political_entity_key = wp.political_entity_key
            THEN 'direct'
            ELSE 'coalition'
        END::text AS result_kind,

        b.votes,
        b.vote_pct,

        b.seats,
        b.seat_pct,

        b.calculated_seats,
        b.calculated_seat_pct,

        b.official_seats,
        b.official_seat_pct,

        b.seat_diff,

        b.is_winner,

        CASE
            WHEN b.political_entity_key = wp.political_entity_key
            THEN wp.color
            ELSE wp.color || '66'
        END::text AS chart_color
    FROM wanted_party wp
    JOIN base_results b
      ON (
            b.political_entity_key = wp.political_entity_key
            OR EXISTS (
                SELECT 1
                FROM wh.bridge_political_entity_member bpm
                WHERE bpm.political_entity_key = b.political_entity_key
                  AND bpm.member_political_entity_key = wp.political_entity_key
            )
         )
)

SELECT
    er.election_year,

    er.display_sigla::text,
    er.display_name::text,
    er.display_color::text,

    er.result_sigla::text,
    er.result_name::text,
    er.result_color::text,

    er.result_kind,

    er.votes,
    er.vote_pct,

    er.seats,
    er.seat_pct,

    er.calculated_seats,
    er.calculated_seat_pct,

    er.official_seats,
    er.official_seat_pct,

    er.seat_diff,

    er.is_winner,

    er.chart_color::text
FROM expanded_results er
ORDER BY
    er.election_year ASC,
    CASE er.result_kind
        WHEN 'direct' THEN 1
        WHEN 'coalition' THEN 2
        ELSE 3
    END,
    er.votes DESC;
$$;
