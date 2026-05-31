CREATE OR REPLACE FUNCTION op.save_candidacy_vote_result(
    p_election_code text,
    p_office_code text,
    p_territory_code text,
    p_sigla text,
    p_entity_type text,
    p_votes int,
    p_display_order int DEFAULT NULL,
    p_import_file_id bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    selected_election_id bigint;
    selected_office_id bigint;
    selected_territory_id bigint;
    selected_entity_id bigint;
    saved_candidacy_id bigint;
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

    selected_entity_id := op.save_political_entity(
        p_sigla,
        p_entity_type
    );

    INSERT INTO op.candidacy (
        election_id,
        office_id,
        territory_id,
        political_entity_id,
        display_order,
        source_label
    )
    VALUES (
        selected_election_id,
        selected_office_id,
        selected_territory_id,
        selected_entity_id,
        p_display_order,
        p_sigla
    )
    ON CONFLICT (election_id, office_id, territory_id, political_entity_id)
    DO UPDATE SET
        display_order = COALESCE(EXCLUDED.display_order, op.candidacy.display_order),
        source_label = EXCLUDED.source_label
    RETURNING candidacy_id
    INTO saved_candidacy_id;

    INSERT INTO op.vote_result (
        election_id,
        office_id,
        territory_id,
        candidacy_id,
        votes,
        import_file_id
    )
    VALUES (
        selected_election_id,
        selected_office_id,
        selected_territory_id,
        saved_candidacy_id,
        COALESCE(p_votes, 0),
        p_import_file_id
    )
    ON CONFLICT (election_id, office_id, territory_id, candidacy_id)
    DO UPDATE SET
        votes = EXCLUDED.votes,
        import_file_id = EXCLUDED.import_file_id,
        updated_at = now();
END;
$$;
