DROP TRIGGER IF EXISTS turnout_refresh_summary_after_write ON op.turnout_result;
DROP TRIGGER IF EXISTS turnout_result_refresh_summary ON op.turnout_result;

CREATE TRIGGER turnout_result_refresh_summary
AFTER INSERT OR UPDATE OR DELETE ON op.turnout_result
FOR EACH ROW
EXECUTE FUNCTION op.refresh_result_summary_after_change();
