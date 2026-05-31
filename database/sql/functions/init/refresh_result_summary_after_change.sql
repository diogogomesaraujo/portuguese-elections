CREATE OR REPLACE FUNCTION op.refresh_result_summary_after_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    changed_row record;
BEGIN
    changed_row := COALESCE(NEW, OLD);

    PERFORM op.refresh_result_summary_for_context(
        changed_row.election_id,
        changed_row.office_id,
        changed_row.territory_id
    );

    RETURN changed_row;
END;
$$;
