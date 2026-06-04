DROP FUNCTION IF EXISTS wh.resolve_vote_territory(text, text, bigint);

CREATE OR REPLACE FUNCTION wh.resolve_vote_territory(
    p_election_type text,
    p_office_code text,
    p_territory_key bigint
)
RETURNS TABLE (
    vote_territory_key bigint,
    vote_territory_level text
)
LANGUAGE sql
STABLE
AS $$
WITH selected AS (
    SELECT
        t.territory_key,
        t.territory_code,
        t.territory_level,
        t.parent_code,
        m.parent_code AS district_code
    FROM wh.dim_territory t
    LEFT JOIN wh.dim_territory m
      ON m.territory_code = t.parent_code
     AND m.territory_level = 'municipality'
    WHERE t.territory_key = p_territory_key
    LIMIT 1
),

base AS (
    SELECT
        territory_key,
        territory_code,
        territory_level,
        parent_code,

        CASE
            WHEN territory_level = 'district'
            THEN territory_code

            WHEN territory_level = 'municipality'
            THEN parent_code

            WHEN territory_level = 'parish'
            THEN district_code

            ELSE territory_code
        END AS raw_district_code,

        CASE
            WHEN territory_level = 'municipality'
            THEN territory_code

            WHEN territory_level = 'parish'
            THEN parent_code

            ELSE territory_code
        END AS raw_municipality_code
    FROM selected
),

resolved AS (
    SELECT
        CASE
            WHEN lower(p_election_type) = 'legislativas'
              OR upper(p_office_code) = 'AR'
            THEN
                CASE
                    WHEN raw_district_code IN ('31', '32') THEN '20'
                    WHEN raw_district_code IN ('41', '42', '43', '44', '45', '46', '47', '48', '49') THEN '19'
                    ELSE raw_district_code
                END

            WHEN upper(p_office_code) = 'AF'
            THEN territory_code

            WHEN upper(p_office_code) IN ('AM', 'CM')
            THEN raw_municipality_code

            WHEN upper(p_office_code) IN ('PR', 'PE')
            THEN 'PT'

            ELSE territory_code
        END AS vote_territory_code,

        CASE
            WHEN lower(p_election_type) = 'legislativas'
              OR upper(p_office_code) = 'AR'
            THEN 'district'

            WHEN upper(p_office_code) = 'AF'
            THEN 'parish'

            WHEN upper(p_office_code) IN ('AM', 'CM')
            THEN 'municipality'

            WHEN upper(p_office_code) IN ('PR', 'PE')
            THEN 'country'

            ELSE territory_level
        END AS vote_territory_level
    FROM base
)

SELECT
    vt.territory_key AS vote_territory_key,
    vt.territory_level::text AS vote_territory_level
FROM resolved r
JOIN wh.dim_territory vt
  ON vt.territory_code = r.vote_territory_code
 AND vt.territory_level = r.vote_territory_level
LIMIT 1;
$$;
