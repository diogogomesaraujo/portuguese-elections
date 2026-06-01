DROP FUNCTION IF EXISTS wh.result_for_territory(text, integer, text, text, text, text);

CREATE OR REPLACE FUNCTION wh.result_for_territory(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_territory_code text,
    p_territory_level text,
    p_party_sigla text DEFAULT NULL
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
WITH wanted_party AS (
    SELECT
        pe.political_entity_key
    FROM wh.dim_political_entity pe
    WHERE lower(pe.sigla) = lower(p_party_sigla)
    LIMIT 1
),

results AS (
    SELECT
        b.*
    FROM wh.party_results(
        p_election_type,
        p_election_year,
        p_office,
        p_territory_code,
        p_territory_level
    ) b
)

SELECT
    r.political_entity_key,
    r.sigla,
    r.name,
    r.entity_type,
    r.color,
    r.votes,
    r.vote_pct,
    r.seats,
    r.seat_pct,
    r.is_winner
FROM results r
LEFT JOIN wanted_party wp
  ON true
WHERE
    (
        p_party_sigla IS NULL
        AND r.is_winner = true
    )
    OR
    (
        p_party_sigla IS NOT NULL
        AND (
            r.political_entity_key = wp.political_entity_key
            OR EXISTS (
                SELECT 1
                FROM wh.bridge_political_entity_member bpm
                WHERE bpm.political_entity_key = r.political_entity_key
                  AND bpm.member_political_entity_key = wp.political_entity_key
            )
        )
    )
ORDER BY
    r.votes DESC,
    r.seats DESC,
    r.sigla ASC
LIMIT 1;
$$;
