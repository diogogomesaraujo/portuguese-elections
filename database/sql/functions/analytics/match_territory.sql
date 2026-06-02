DROP FUNCTION IF EXISTS wh.match_territory(text, text, text);

CREATE OR REPLACE FUNCTION wh.resolve_best_territory(
    p_parish_name text,
    p_municipality_name text,
    p_district_name text
)
RETURNS TABLE (
    territory_key bigint
)
LANGUAGE sql
STABLE
AS $$
WITH candidates AS (
    SELECT
        parish.territory_key,
        parish.territory_code,
        parish.territory_name,
        parish.territory_level,
        1 AS priority
    FROM wh.dim_territory parish
    JOIN wh.dim_territory municipality
      ON municipality.territory_code = parish.parent_code
    JOIN wh.dim_territory district
      ON district.territory_code = municipality.parent_code
    WHERE lower(parish.territory_name) = lower(p_parish_name)
      AND lower(municipality.territory_name) = lower(p_municipality_name)
      AND lower(district.territory_name) = lower(p_district_name)

    UNION ALL

    SELECT
        municipality.territory_key,
        municipality.territory_code,
        municipality.territory_name,
        municipality.territory_level,
        2 AS priority
    FROM wh.dim_territory municipality
    JOIN wh.dim_territory district
      ON district.territory_code = municipality.parent_code
    WHERE lower(municipality.territory_name) = lower(p_municipality_name)
      AND lower(district.territory_name) = lower(p_district_name)

    UNION ALL

    SELECT
        district.territory_key,
        district.territory_code,
        district.territory_name,
        district.territory_level,
        3 AS priority
    FROM wh.dim_territory district
    WHERE lower(district.territory_name) = lower(p_district_name)
      AND district.territory_level = 'district'

    UNION ALL

    SELECT
        country.territory_key,
        country.territory_code,
        country.territory_name,
        country.territory_level,
        4 AS priority
    FROM wh.dim_territory country
    WHERE country.territory_level = 'country'
)
SELECT
    c.territory_key
FROM candidates c
ORDER BY c.priority
LIMIT 1;
$$;