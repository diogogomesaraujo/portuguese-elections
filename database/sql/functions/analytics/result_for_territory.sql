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
                      sigla text,
                      name text,
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
        e.election_key,
        e.election_type,
        o.office_key,
        o.office_code
    FROM wh.dim_election e
             CROSS JOIN wh.dim_office o
    WHERE lower(e.election_type) = lower(p_election_type)
      AND e.election_year = p_election_year
      AND (
        lower(o.office_code) = lower(p_office)
            OR lower(o.office_name) = lower(p_office)
        )
      AND EXISTS (
        SELECT 1
        FROM wh.fact_vote_result fvr
        WHERE fvr.election_key = e.election_key
          AND fvr.office_key   = o.office_key
    )
    LIMIT 1
),

     target AS (
         SELECT
             t.territory_key,
             t.territory_code,
             t.territory_level,
             t.parent_code,
             parent.territory_code  AS parent_territory_code,
             parent.territory_level AS parent_territory_level,
             grandparent.territory_code  AS grandparent_territory_code,
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
         SELECT vt.territory_key
         FROM selected s
                  JOIN target tg ON true
                  JOIN wh.dim_territory vt
                       ON vt.territory_level = 'district'
                           AND vt.territory_code =
                               CASE
                                   WHEN tg.territory_level = 'district'     THEN tg.territory_code
                                   WHEN tg.territory_level = 'municipality' THEN tg.parent_code
                                   WHEN tg.territory_level = 'parish'       THEN tg.grandparent_territory_code
                                   ELSE tg.territory_code
                                   END
         WHERE lower(s.election_type) = 'legislativas'
            OR upper(s.office_code) = 'AR'

         UNION ALL

         SELECT vt.territory_key
         FROM selected s
                  JOIN target tg ON true
                  JOIN wh.dim_territory vt
                       ON vt.territory_level = 'municipality'
                           AND (
                              (tg.territory_level = 'district'     AND vt.parent_code    = tg.territory_code)
                                  OR (tg.territory_level = 'municipality' AND vt.territory_code = tg.territory_code)
                                  OR (tg.territory_level = 'parish'       AND vt.territory_code = tg.parent_code)
                              )
         WHERE upper(s.office_code) IN ('CM', 'AM')

         UNION ALL

         SELECT vt.territory_key
         FROM selected s
                  JOIN target tg ON true
                  JOIN wh.dim_territory vt
                       ON vt.territory_level = 'parish'
                  LEFT JOIN wh.dim_territory parent_municipality
                            ON parent_municipality.territory_code = vt.parent_code
                                AND parent_municipality.territory_level = 'municipality'
         WHERE upper(s.office_code) = 'AF'
           AND (
             (tg.territory_level = 'district'     AND parent_municipality.parent_code = tg.territory_code)
                 OR (tg.territory_level = 'municipality' AND vt.parent_code    = tg.territory_code)
                 OR (tg.territory_level = 'parish'       AND vt.territory_code = tg.territory_code)
             )

         UNION ALL

         SELECT vt.territory_key
         FROM selected s
                  JOIN wh.dim_territory vt
                       ON vt.territory_level = 'country'
                           AND vt.territory_code = 'PT'
         WHERE upper(s.office_code) IN ('PR', 'PE')
     ),

     party_totals AS (
         SELECT
             pe.sigla,
             pe.name,
             pe.color,
             SUM(fvr.votes)::bigint               AS votes,
             SUM(COALESCE(fsr.seats, 0))::integer AS seats
         FROM selected s
                  JOIN vote_territories vt ON true
                  JOIN wh.fact_vote_result fvr
                       ON fvr.election_key   = s.election_key
                           AND fvr.office_key    = s.office_key
                           AND fvr.territory_key = vt.territory_key
                  JOIN wh.dim_political_entity pe
                       ON pe.political_entity_key = fvr.political_entity_key
                  LEFT JOIN wh.fact_seat_result fsr
                            ON fsr.election_key          = fvr.election_key
                                AND fsr.office_key           = fvr.office_key
                                AND fsr.territory_key        = fvr.territory_key
                                AND fsr.political_entity_key = fvr.political_entity_key
         GROUP BY pe.sigla, pe.name, pe.color
     ),

     ranked AS (
         SELECT
             *,
             SUM(votes) OVER () AS total_votes,
             SUM(seats) OVER () AS total_seats,
             row_number() OVER (ORDER BY votes DESC, sigla) AS rn
         FROM party_totals
     )

SELECT
    ranked.sigla::text,
    ranked.name::text,
    ranked.color::text,
    ranked.votes,
    CASE
        WHEN ranked.total_votes > 0
            THEN round((ranked.votes::numeric / ranked.total_votes::numeric) * 100, 2)
        END AS vote_pct,
    ranked.seats,
    CASE
        WHEN ranked.total_seats > 0
            THEN round((ranked.seats::numeric / ranked.total_seats::numeric) * 100, 2)
        END AS seat_pct,
    ranked.rn = 1 AS is_winner
FROM ranked
WHERE
    (p_party_sigla IS NULL     AND ranked.rn = 1)
   OR (p_party_sigla IS NOT NULL AND lower(ranked.sigla) = lower(p_party_sigla))
LIMIT 1;
$$;
