DROP TRIGGER IF EXISTS vote_refresh_summary_after_write ON op.vote_result;
DROP TRIGGER IF EXISTS vote_result_refresh_summary ON op.vote_result;

CREATE TRIGGER vote_result_refresh_summary
AFTER INSERT OR UPDATE OR DELETE ON op.vote_result
FOR EACH ROW
EXECUTE FUNCTION op.refresh_result_summary_after_change();
