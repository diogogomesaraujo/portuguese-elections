CREATE OR REPLACE FUNCTION op.save_turnout_result(
    p_election_code text,
    p_office_code text,
    p_territory_code text,
    p_registered_voters int,
    p_voters int,
    p_blank_votes int,
    p_null_votes int,
    p_import_file_id bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    selected_election_id bigint;
    selected_office_id bigint;
    selected_territory_id bigint;
BEGIN
    SELECT election_id
    INTO selected_election_id
    FROM op.election
    WHERE code = p_election_code;

    SELECT office_id
    INTO selected_office_id
    FROM op.office
    WHERE code = p_office_code;

    SELECT territory_id
    INTO selected_territory_id
    FROM op.territory
    WHERE code = p_territory_code;

    IF selected_election_id IS NULL THEN
        RAISE EXCEPTION 'unknown election code %', p_election_code;
    END IF;

    IF selected_office_id IS NULL THEN
        RAISE EXCEPTION 'unknown office code %', p_office_code;
    END IF;

    IF selected_territory_id IS NULL THEN
        RAISE EXCEPTION 'unknown territory code %', p_territory_code;
    END IF;

    INSERT INTO op.turnout_result (
        election_id,
        office_id,
        territory_id,
        registered_voters,
        voters,
        blank_votes,
        null_votes,
        import_file_id
    )
    VALUES (
        selected_election_id,
        selected_office_id,
        selected_territory_id,
        COALESCE(p_registered_voters, 0),
        COALESCE(p_voters, 0),
        COALESCE(p_blank_votes, 0),
        COALESCE(p_null_votes, 0),
        p_import_file_id
    )
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        registered_voters = EXCLUDED.registered_voters,
        voters = EXCLUDED.voters,
        blank_votes = EXCLUDED.blank_votes,
        null_votes = EXCLUDED.null_votes,
        import_file_id = EXCLUDED.import_file_id,
        updated_at = now();
END;
$$;
