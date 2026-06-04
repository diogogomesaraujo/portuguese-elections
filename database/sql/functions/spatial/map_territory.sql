DROP FUNCTION IF EXISTS map_territory(
    text, integer, text, text, text, text, text, text, text, integer
);
DROP FUNCTION IF EXISTS map_territory(
    text, integer, text, text, text, text, text, text, text, text, integer
);

CREATE OR REPLACE FUNCTION map_territory(
    p_election_type  text,
    p_election_year  integer,
    p_office         text,
    p_territory_key  bigint,
    p_party_sigla    text,
    stroke           text,
    strokewidth      text,
    fill             text,
    fillopacity      text,
    precision_value  integer
)
    RETURNS text AS
$$
DECLARE
    svg              text;
    v_level          text;
    v_child_level    text;
    p_territory_code text;
BEGIN
    SELECT territory_level, territory_code, territory_key
    INTO v_level, p_territory_code
    FROM wh.dim_territory
    WHERE territory_key = p_territory_key;

    v_child_level := CASE v_level
                         WHEN 'country'      THEN 'district'
                         WHEN 'district'     THEN 'municipality'
                         WHEN 'municipality' THEN 'parish'
                         ELSE NULL
        END;

    IF v_level = 'country' THEN
        precision_value := precision_value * 300;
        strokewidth := CAST(CAST(strokewidth AS bigint) * 20 AS text);
    END IF;

    WITH draw AS (
        SELECT
            t.territory_code,
            t.territory_key,
            t.territory_name,
            t.territory_level,
            t.parent_name,
            CASE
                WHEN NOT ST_IsEmpty(
                        ST_SimplifyPreserveTopology(
                                ST_CollectionExtract(
                                        ST_MakeValid(ST_Transform(t.geom, 3763)),
                                        3
                                ),
                                precision_value
                        )
                         )
                    THEN ST_SimplifyPreserveTopology(
                        ST_CollectionExtract(
                                ST_MakeValid(ST_Transform(t.geom, 3763)),
                                3
                        ),
                        precision_value
                         )
                ELSE ST_CollectionExtract(
                        ST_MakeValid(ST_Transform(t.geom, 3763)),
                        3
                     )
                END AS geom
        FROM wh.dim_territory t
        WHERE t.geom IS NOT NULL
          AND (
            p_territory_code IS NULL
                OR (
                v_child_level IS NOT NULL
                    AND t.territory_level = v_child_level
                    AND t.parent_code = p_territory_code
                )
                OR (
                v_child_level IS NULL
                    AND t.territory_code = p_territory_code
                )
            )
          AND NOT (
            t.territory_level = 'district'
                AND t.territory_code IN ('21', '22')
            )
    ),

         final AS (
             SELECT
                 d.territory_code,
                 d.territory_name,
                 d.territory_level,
                 d.parent_name,
                 d.geom,
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
                     d.territory_key,
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
                                           stroke      => stroke::text,
                                           strokewidth => strokewidth::text,
                                           fill        => COALESCE(result_color, fill)::text,
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
    IMMUTABLE;
