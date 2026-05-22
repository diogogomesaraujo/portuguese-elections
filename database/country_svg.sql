WITH district_geoms AS (
    SELECT
        distrito_ilha,
        st_union(st_simplifypreservetopology(geom, 50)) as geom
    FROM cont_freguesias
    GROUP BY distrito_ilha
)

SELECT distrito_ilha, svgshape(st_translate(st_convexhull(geom), -st_xmin(geom), -st_ymin(geom)), title => distrito_ilha, style => svgStyle(  'stroke', '#ffffff',
                                                                                                                                              'stroke-width', 0.1::text,
                                                                                                                                              'fill', 'url(#state)',
                                                                                                                                              'stroke-linejoin', 'round' )) FROM district_geoms;