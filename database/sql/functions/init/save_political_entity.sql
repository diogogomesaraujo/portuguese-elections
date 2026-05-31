CREATE OR REPLACE FUNCTION op.save_political_entity(
    p_sigla text,
    p_entity_type text DEFAULT 'party'
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    saved_entity_id bigint;
    saved_member_id bigint;
    member_sigla text;
    normalized_sigla text := trim(p_sigla);
BEGIN
    IF normalized_sigla IS NULL OR normalized_sigla = '' THEN
        RAISE EXCEPTION 'empty political entity sigla';
    END IF;

    INSERT INTO op.political_entity (
        sigla,
        entity_type
    )
    VALUES (
        normalized_sigla,
        p_entity_type
    )
    ON CONFLICT (sigla)
    DO UPDATE SET
        entity_type = CASE
            WHEN op.political_entity.entity_type = 'party'
             AND EXCLUDED.entity_type IN ('coalition', 'gce')
            THEN EXCLUDED.entity_type
            ELSE op.political_entity.entity_type
        END,
        updated_at = now()
    RETURNING political_entity_id
    INTO saved_entity_id;

    IF p_entity_type = 'coalition' AND position('.' in normalized_sigla) > 0 THEN
        FOREACH member_sigla IN ARRAY string_to_array(normalized_sigla, '.') LOOP
            member_sigla := trim(member_sigla);

            IF member_sigla <> '' THEN
                INSERT INTO op.political_entity (
                    sigla,
                    entity_type
                )
                VALUES (
                    member_sigla,
                    'party'
                )
                ON CONFLICT (sigla)
                DO NOTHING
                RETURNING political_entity_id
                INTO saved_member_id;

                IF saved_member_id IS NULL THEN
                    SELECT political_entity_id
                    INTO saved_member_id
                    FROM op.political_entity
                    WHERE sigla = member_sigla;
                END IF;

                INSERT INTO op.political_entity_member (
                    coalition_id,
                    member_id
                )
                VALUES (
                    saved_entity_id,
                    saved_member_id
                )
                ON CONFLICT
                DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    RETURN saved_entity_id;
END;
$$;
