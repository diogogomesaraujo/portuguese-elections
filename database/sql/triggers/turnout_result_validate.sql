DROP TRIGGER IF EXISTS turnout_validate_before_write ON op.turnout_result;
DROP TRIGGER IF EXISTS turnout_result_validate ON op.turnout_result;

CREATE TRIGGER turnout_result_validate
BEFORE INSERT OR UPDATE ON op.turnout_result
FOR EACH ROW
EXECUTE FUNCTION op.validate_turnout_result();
