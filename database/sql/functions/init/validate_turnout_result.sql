CREATE OR REPLACE FUNCTION op.validate_turnout_result()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.voters > NEW.registered_voters THEN
        RAISE EXCEPTION
            'voters (%) cannot exceed registered voters (%)',
            NEW.voters,
            NEW.registered_voters;
    END IF;

    IF NEW.blank_votes + NEW.null_votes > NEW.voters THEN
        RAISE EXCEPTION
            'blank + null votes (%) cannot exceed voters (%)',
            NEW.blank_votes + NEW.null_votes,
            NEW.voters;
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
