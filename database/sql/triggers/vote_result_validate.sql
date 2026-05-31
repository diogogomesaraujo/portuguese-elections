DROP TRIGGER IF EXISTS vote_validate_before_write ON op.vote_result;
DROP TRIGGER IF EXISTS vote_result_validate ON op.vote_result;

CREATE TRIGGER vote_result_validate
BEFORE INSERT OR UPDATE ON op.vote_result
FOR EACH ROW
EXECUTE FUNCTION op.validate_vote_result();
