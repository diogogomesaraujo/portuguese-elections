-- Makes sure no party has negative mandates

CREATE OR REPLACE FUNCTION validate_mandates()
RETURNS TRIGGER
AS
$$
BEGIN
    IF NEW.mandates < 0 THEN
        RAISE EXCEPTION
        'Mandates cannot be negative';
    END IF;
    RETURN NEW;
END;
$$ 
LANGUAGE plpgsql;


CREATE TRIGGER check_mandates
BEFORE INSERT OR UPDATE ON results
FOR EACH ROW
EXECUTE FUNCTION validate_mandates();


-- Computes automatically the vote percentage

CREATE OR REPLACE FUNCTION calculate_vote_percentage()
RETURNS TRIGGER
AS
$$
DECLARE
    total_valid_votes BIGINT;
BEGIN
    SELECT valid_votes
    INTO total_valid_votes
    FROM participation
    WHERE district_id = NEW.district_id;
    NEW.vote_percentage := ROUND((NEW.votes::numeric / total_valid_votes) * 100, 2);
    RETURN NEW;
END;
$$ 
LANGUAGE plpgsql;


CREATE TRIGGER auto_calculate_vote_percentage
BEFORE INSERT OR UPDATE ON results
FOR EACH ROW
EXECUTE FUNCTION calculate_vote_percentage();