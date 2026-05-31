CREATE OR REPLACE FUNCTION op.normalize_territory_name()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.normalized_name := lower(unaccent(coalesce(NEW.name, '')));
    RETURN NEW;
END;
$$;
