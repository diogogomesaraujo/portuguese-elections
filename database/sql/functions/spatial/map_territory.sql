CREATE OR REPLACE FUNCTION map_territory(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_draw_level text,
    p_parent_name text,
    p_territory_name text,
    p_party_sigla text,
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
    WITH draw AS (
        SELECT
            t.territory_code,
            t.territory_name,
            t.territory_level,
            t.parent_name,
            ST_SimplifyPreserveTopology(
                ST_CollectionExtract(
                    ST_MakeValid(ST_Transform(t.geom, 3763)),
                    3
                ),
                precision_value
            ) AS geom
        FROM wh.dim_territory t
        WHERE t.territory_level = p_draw_level
        AND t.geom IS NOT NULL
        AND (
            p_parent_name IS NULL
            OR lower(unaccent(t.parent_name)) = lower(unaccent(p_parent_name))
        )
        AND (
            p_territory_name IS NULL
            OR lower(unaccent(t.territory_name)) = lower(unaccent(p_territory_name))
        )
        AND NOT (
            p_draw_level = 'district'
            AND t.territory_code IN ('21', '22')
        )
    ),

    final AS (
        SELECT
            d.*,
            r.sigla,
            r.name,
            COALESCE(r.color, fill) AS result_color,
            r.votes,
            r.vote_pct,
            r.seats,
            r.seat_pct,
            r.is_winner
        FROM draw d
        LEFT JOIN LATERAL wh.result_for_territory(
            p_election_type,
            p_election_year,
            p_office,
            d.territory_code,
            d.territory_level,
            p_party_sigla
        ) r ON true
        WHERE d.geom IS NOT NULL
          AND NOT ST_IsEmpty(d.geom)
    )

    SELECT svgdoc(
        content => array_agg(
            svgshape(
                geom,
                title =>
                    territory_name
                    || COALESCE(' / ' || parent_name, '')
                    || CASE
                        WHEN sigla IS NOT NULL AND is_winner
                        THEN ' / Winner: ' || sigla
                           || ' / ' || votes::text || ' votes'
                           || ' / ' || vote_pct::text || '%'

                        WHEN sigla IS NOT NULL
                        THEN ' / Party: ' || sigla
                           || ' / ' || votes::text || ' votes'
                           || ' / ' || vote_pct::text || '%'

                        ELSE ''
                    END
                    || CASE
                        WHEN seats IS NOT NULL
                        THEN ' / ' || seats::text || ' seats'
                        ELSE ''
                    END,
                style => svgstyleprop(
                    stroke => stroke::text,
                    strokewidth => strokewidth::text,
                    fill => COALESCE(result_color, fill)::text,
                    fillopacity => fillopacity::text
                )
            )
            ORDER BY territory_code
        ),
        viewbox => svgviewbox(ST_Collect(geom))
    )
    INTO svg
    FROM final;

    RETURN COALESCE(svg, '');
END;
$$
LANGUAGE plpgsql
STABLE;
