DROP FUNCTION IF EXISTS wh.resolve_match_territory(text, text, text);

CREATE OR REPLACE FUNCTION wh.resolve_match_territory(
    p_parish_name       text,
    p_municipality_name text,
    p_district_name     text
)
    RETURNS TABLE (
                      territory_code text
                  )
    LANGUAGE sql
    STABLE
AS $$
WITH candidates AS (
    -- Parish level: only attempt if all three names are provided
    SELECT
        parish.territory_code,
        1 AS priority
    FROM wh.dim_territory parish
             JOIN wh.dim_territory municipality
                  ON municipality.territory_code = parish.parent_code
             JOIN wh.dim_territory district
                  ON district.territory_code = municipality.parent_code
    WHERE p_parish_name IS NOT NULL
      AND p_municipality_name IS NOT NULL
      AND p_district_name IS NOT NULL
      AND lower(parish.territory_name)       = lower(p_parish_name)
      AND lower(municipality.territory_name) = lower(p_municipality_name)
      AND lower(district.territory_name)     = lower(p_district_name)

    UNION ALL

    SELECT
        municipality.territory_code,
        2 AS priority
    FROM wh.dim_territory municipality
             JOIN wh.dim_territory district
                  ON district.territory_code = municipality.parent_code
    WHERE p_municipality_name IS NOT NULL
      AND p_district_name IS NOT NULL
      AND lower(municipality.territory_name) = lower(p_municipality_name)
      AND lower(district.territory_name)     = lower(p_district_name)

    UNION ALL

    SELECT
        district.territory_code,
        3 AS priority
    FROM wh.dim_territory district
    WHERE p_district_name IS NOT NULL
      AND lower(district.territory_name) = lower(p_district_name)
      AND district.territory_level = 'district'

    UNION ALL

    SELECT
        country.territory_code,
        4 AS priority
    FROM wh.dim_territory country
    WHERE country.territory_level = 'country'
)
SELECT
    c.territory_code
FROM candidates c
ORDER BY c.priority
LIMIT 1;
$$;