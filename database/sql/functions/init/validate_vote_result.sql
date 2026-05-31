CREATE OR REPLACE FUNCTION op.validate_vote_result()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    linked_candidacy record;
BEGIN
    SELECT
        election_id,
        office_id,
        territory_id
    INTO linked_candidacy
    FROM op.candidacy
    WHERE candidacy_id = NEW.candidacy_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'candidacy % does not exist',
            NEW.candidacy_id;
    END IF;

    IF linked_candidacy.election_id <> NEW.election_id
       OR linked_candidacy.office_id <> NEW.office_id
       OR linked_candidacy.territory_id <> NEW.territory_id THEN
        RAISE EXCEPTION
            'vote_result context does not match candidacy context';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
