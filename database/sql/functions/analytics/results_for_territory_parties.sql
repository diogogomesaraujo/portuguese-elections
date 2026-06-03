DROP FUNCTION IF EXISTS wh.results_for_territory_parties(text, integer, text, text);
DROP FUNCTION IF EXISTS wh.results_for_territory_parties(text, integer, text, bigint);

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
    SELECT
        b.political_entity_key,
        b.sigla,
        b.name,
        b.entity_type,
        b.color,
        b.votes,
        b.vote_pct,
        b.seats,
        b.seat_pct,
        b.is_winner
    FROM wh.party_results(
        p_election_type,
        p_election_year,
        p_office,
        p_territory_key
    ) b
    WHERE b.votes > 0
       OR b.seats > 0
    ORDER BY
        wh.political_entity_order(b.sigla) ASC,
        b.seats DESC,
        b.votes DESC,
        b.sigla ASC;
$$;

CREATE OR REPLACE FUNCTION wh.results_for_territory_parties(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_territory_code text
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
WITH territory AS (
    SELECT
        t.territory_key
    FROM wh.dim_territory t
    WHERE t.territory_code = p_territory_code
    LIMIT 1
)
SELECT
    b.political_entity_key,
    b.sigla,
    b.name,
    b.entity_type,
    b.color,
    b.votes,
    b.vote_pct,
    b.seats,
    b.seat_pct,
    b.is_winner
FROM territory t
JOIN LATERAL wh.results_for_territory_parties(
    p_election_type,
    p_election_year,
    p_office,
    t.territory_key
) b
  ON true
ORDER BY
    wh.political_entity_order(b.sigla) ASC,
    b.seats DESC,
    b.votes DESC,
    b.sigla ASC;
$$;
