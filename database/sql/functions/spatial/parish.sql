CREATE OR REPLACE FUNCTION parish(
    election_type text,
    election_year integer,
    office text,
    parish_name text,
    stroke text,
    strokewidth text,
    fill text,
    fillopacity text,
    precision_value integer
)
RETURNS text AS
$$
DECLARE
    svg text;
BEGIN
    WITH parish_base AS (
        SELECT
            p.territory_code AS parish_code,
            p.territory_name AS parish_name,
            p.parent_code AS municipality_code,
            p.parent_name AS municipality_name,

            m.parent_code AS district_code,
            d.territory_name AS district_name,

            CASE
                -- AR Madeira circle
                WHEN m.parent_code IN ('31', '32') THEN '20'

                -- AR Açores circle
                WHEN m.parent_code IN ('41', '42', '43', '44', '45', '46', '47', '48', '49') THEN '19'

                -- Continental district
                ELSE m.parent_code
            END AS ar_circle_code,

            ST_SimplifyPreserveTopology(
                ST_CollectionExtract(
                    ST_Scale(
                        ST_Transform(p.geom, 4326),
                        10000,
                        10000
                    ),
                    3
                ),
                precision_value
            ) AS geom
        FROM wh.dim_territory p
        LEFT JOIN wh.dim_territory m
          ON m.territory_code = p.parent_code
         AND m.territory_level = 'municipality'
        LEFT JOIN wh.dim_territory d
          ON d.territory_code = m.parent_code
         AND d.territory_level = 'district'
        WHERE p.territory_level = 'parish'
          AND lower(unaccent(p.territory_name)) = lower(unaccent(parish.parish_name))
          AND p.geom IS NOT NULL
    ),

    target AS (
        SELECT
            pb.*,
            e.election_key,
            o.office_key,
            o.office_code,

            CASE
                WHEN lower(e.election_type) = 'legislativas'
                  OR o.office_code = 'AR'
                THEN pb.ar_circle_code

                WHEN o.office_code = 'AF'
                THEN pb.parish_code

                WHEN o.office_code IN ('AM', 'CM')
                THEN pb.municipality_code

                WHEN o.office_code IN ('PR', 'PE')
                THEN 'PT'

                ELSE pb.parish_code
            END AS vote_territory_code,

            CASE
                WHEN lower(e.election_type) = 'legislativas'
                  OR o.office_code = 'AR'
                THEN 'district'

                WHEN o.office_code = 'AF'
                THEN 'parish'

                WHEN o.office_code IN ('AM', 'CM')
                THEN 'municipality'

                WHEN o.office_code IN ('PR', 'PE')
                THEN 'country'

                ELSE 'parish'
            END AS vote_territory_level
        FROM parish_base pb
        JOIN wh.dim_election e
          ON lower(e.election_type) = lower(parish.election_type)
         AND e.election_year = parish.election_year
        JOIN wh.dim_office o
          ON lower(o.office_code) = lower(parish.office)
          OR lower(o.office_name) = lower(parish.office)
    ),

    final AS (
        SELECT
            t.parish_code,
            t.parish_name,
            t.municipality_name,
            t.district_name,
            t.geom,

            pe.sigla AS winner_sigla,
            COALESCE(pe.color, fill) AS winner_color,
            fvr.votes AS winner_votes,
            round(fvr.vote_share * 100, 2) AS winner_pct
        FROM target t
        LEFT JOIN wh.dim_territory vote_t
          ON vote_t.territory_code = t.vote_territory_code
         AND vote_t.territory_level = t.vote_territory_level
        LEFT JOIN wh.fact_vote_result fvr
          ON fvr.election_key = t.election_key
         AND fvr.office_key = t.office_key
         AND fvr.territory_key = vote_t.territory_key
         AND fvr.result_rank = 1
        LEFT JOIN wh.dim_political_entity pe
          ON pe.political_entity_key = fvr.political_entity_key
    )

    SELECT svgdoc(
        content => array_agg(
            svgshape(
                ST_CollectionExtract(geom, 3),
                title =>
                    parish_name
                    || ' / ' || municipality_name
                    || COALESCE(' / ' || district_name, '')
                    || CASE
                        WHEN winner_sigla IS NOT NULL
                        THEN ' / Elected: ' || winner_sigla
                           || ' / ' || winner_votes::text || ' votos'
                           || ' / ' || winner_pct::text || '%'
                        ELSE ''
                    END,
                style => svgstyleprop(
                    stroke => stroke::text,
                    strokewidth => strokewidth::text,
                    fill => COALESCE(winner_color, fill)::text,
                    fillopacity => fillopacity::text
                )
            )
            ORDER BY parish_code
        ),
        viewbox => svgviewbox(ST_Collect(geom))
    )
    INTO svg
    FROM final
    WHERE geom IS NOT NULL
      AND NOT ST_IsEmpty(geom);

    RETURN svg;
END;
$$
LANGUAGE plpgsql
STABLE;
