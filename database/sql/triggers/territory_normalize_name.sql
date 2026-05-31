DROP TRIGGER IF EXISTS territory_normalize_name_before_write ON op.territory;
DROP TRIGGER IF EXISTS territory_normalize_name ON op.territory;

CREATE TRIGGER territory_normalize_name
BEFORE INSERT OR UPDATE OF name ON op.territory
FOR EACH ROW
EXECUTE FUNCTION op.normalize_territory_name();
