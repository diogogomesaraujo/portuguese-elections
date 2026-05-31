CREATE OR REPLACE PROCEDURE op.populate_seat_count()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM op.seat_count
    WHERE source IN (
        'portugal_cm_rule',
        'portugal_af_rule',
        'portugal_am_direct_rule'
    );

    -- CM: Câmara Municipal
    -- Total seats = president + vereadores.
    INSERT INTO op.seat_count (
        election_id,
        office_id,
        territory_id,
        seats,
        source
    )
    SELECT
        tr.election_id,
        tr.office_id,
        tr.territory_id,
        CASE
            WHEN lower(unaccent(t.name)) = 'lisboa' THEN 17
            WHEN lower(unaccent(t.name)) = 'porto' THEN 13
            WHEN tr.registered_voters >= 100000 THEN 11
            WHEN tr.registered_voters > 50000 THEN 9
            WHEN tr.registered_voters > 10000 THEN 7
            ELSE 5
        END AS seats,
        'portugal_cm_rule'
    FROM op.turnout_result tr
    JOIN op.office o
      ON o.office_id = tr.office_id
    JOIN op.territory t
      ON t.territory_id = tr.territory_id
    WHERE o.code = 'CM'
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        seats = EXCLUDED.seats,
        source = EXCLUDED.source;

    -- AF: Assembleia de Freguesia.
    INSERT INTO op.seat_count (
        election_id,
        office_id,
        territory_id,
        seats,
        source
    )
    SELECT
        tr.election_id,
        tr.office_id,
        tr.territory_id,
        CASE
            WHEN tr.registered_voters > 30000 THEN
                CASE
                    WHEN (
                        19 + CEIL((tr.registered_voters - 30000)::numeric / 10000)::int
                    ) % 2 = 0
                    THEN
                        19 + CEIL((tr.registered_voters - 30000)::numeric / 10000)::int + 1
                    ELSE
                        19 + CEIL((tr.registered_voters - 30000)::numeric / 10000)::int
                END
            WHEN tr.registered_voters > 20000 THEN 19
            WHEN tr.registered_voters > 5000 THEN 13
            WHEN tr.registered_voters > 1000 THEN 9
            ELSE 7
        END AS seats,
        'portugal_af_rule'
    FROM op.turnout_result tr
    JOIN op.office o
      ON o.office_id = tr.office_id
    WHERE o.code = 'AF'
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        seats = EXCLUDED.seats,
        source = EXCLUDED.source;

    -- AM: Assembleia Municipal, directly elected members only.
    -- Rule:
    -- direct members > number of parish presidents
    -- direct members >= 3 * number of CM members
    INSERT INTO op.seat_count (
        election_id,
        office_id,
        territory_id,
        seats,
        source
    )
    WITH cm_seats AS (
        SELECT
            tr.election_id,
            tr.territory_id,
            CASE
                WHEN lower(unaccent(t.name)) = 'lisboa' THEN 17
                WHEN lower(unaccent(t.name)) = 'porto' THEN 13
                WHEN tr.registered_voters >= 100000 THEN 11
                WHEN tr.registered_voters > 50000 THEN 9
                WHEN tr.registered_voters > 10000 THEN 7
                ELSE 5
            END AS cm_members
        FROM op.turnout_result tr
        JOIN op.office o
          ON o.office_id = tr.office_id
        JOIN op.territory t
          ON t.territory_id = tr.territory_id
        WHERE o.code = 'CM'
    ),

    parish_counts AS (
        SELECT
            tr.election_id,
            municipality.territory_id AS municipality_id,
            COUNT(*)::int AS parish_presidents
        FROM op.turnout_result tr
        JOIN op.office o
          ON o.office_id = tr.office_id
        JOIN op.territory parish
          ON parish.territory_id = tr.territory_id
        JOIN op.territory municipality
          ON municipality.territory_id = parish.parent_id
        WHERE o.code = 'AF'
        GROUP BY
            tr.election_id,
            municipality.territory_id
    )

    SELECT
        tr.election_id,
        tr.office_id,
        tr.territory_id,
        GREATEST(
            COALESCE(pc.parish_presidents, 0) + 1,
            3 * cm.cm_members
        ) AS seats,
        'portugal_am_direct_rule'
    FROM op.turnout_result tr
    JOIN op.office o
      ON o.office_id = tr.office_id
    JOIN cm_seats cm
      ON cm.election_id = tr.election_id
     AND cm.territory_id = tr.territory_id
    LEFT JOIN parish_counts pc
      ON pc.election_id = tr.election_id
     AND pc.municipality_id = tr.territory_id
    WHERE o.code = 'AM'
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        seats = EXCLUDED.seats,
        source = EXCLUDED.source;
END;
$$;
