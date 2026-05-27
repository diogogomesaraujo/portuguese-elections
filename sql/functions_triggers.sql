CREATE OR REPLACE FUNCTION op.normalize_territory_name()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.normalized_name := lower(unaccent(coalesce(NEW.name, '')));
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS territory_normalize_name_before_write ON op.territory;
DROP TRIGGER IF EXISTS territory_normalize_name ON op.territory;

CREATE TRIGGER territory_normalize_name
BEFORE INSERT OR UPDATE OF name ON op.territory
FOR EACH ROW
EXECUTE FUNCTION op.normalize_territory_name();


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

DROP TRIGGER IF EXISTS turnout_validate_before_write ON op.turnout_result;
DROP TRIGGER IF EXISTS turnout_result_validate ON op.turnout_result;

CREATE TRIGGER turnout_result_validate
BEFORE INSERT OR UPDATE ON op.turnout_result
FOR EACH ROW
EXECUTE FUNCTION op.validate_turnout_result();


CREATE OR REPLACE FUNCTION op.validate_vote_result()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    linked_candidacy record;
BEGIN
    SELECT
        election_id,
        office_id,
        territory_id
    INTO linked_candidacy
    FROM op.candidacy
    WHERE candidacy_id = NEW.candidacy_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'candidacy % does not exist',
            NEW.candidacy_id;
    END IF;

    IF linked_candidacy.election_id <> NEW.election_id
       OR linked_candidacy.office_id <> NEW.office_id
       OR linked_candidacy.territory_id <> NEW.territory_id THEN
        RAISE EXCEPTION
            'vote_result context does not match candidacy context';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS vote_validate_before_write ON op.vote_result;
DROP TRIGGER IF EXISTS vote_result_validate ON op.vote_result;

CREATE TRIGGER vote_result_validate
BEFORE INSERT OR UPDATE ON op.vote_result
FOR EACH ROW
EXECUTE FUNCTION op.validate_vote_result();


CREATE OR REPLACE FUNCTION op.refresh_result_summary_for_context(
    p_election_id bigint,
    p_office_id bigint,
    p_territory_id bigint
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO op.result_summary (
        election_id,
        office_id,
        territory_id,
        registered_voters,
        voters,
        blank_votes,
        null_votes,
        candidate_votes,
        turnout_rate,
        blank_rate,
        null_rate,
        updated_at
    )
    SELECT
        turnout.election_id,
        turnout.office_id,
        turnout.territory_id,
        turnout.registered_voters,
        turnout.voters,
        turnout.blank_votes,
        turnout.null_votes,
        COALESCE(SUM(vote.votes), 0)::int AS candidate_votes,
        CASE
            WHEN turnout.registered_voters > 0
            THEN round(turnout.voters::numeric / turnout.registered_voters, 6)
        END AS turnout_rate,
        CASE
            WHEN turnout.voters > 0
            THEN round(turnout.blank_votes::numeric / turnout.voters, 6)
        END AS blank_rate,
        CASE
            WHEN turnout.voters > 0
            THEN round(turnout.null_votes::numeric / turnout.voters, 6)
        END AS null_rate,
        now()
    FROM op.turnout_result turnout
    LEFT JOIN op.vote_result vote
      ON vote.election_id = turnout.election_id
     AND vote.office_id = turnout.office_id
     AND vote.territory_id = turnout.territory_id
    WHERE turnout.election_id = p_election_id
      AND turnout.office_id = p_office_id
      AND turnout.territory_id = p_territory_id
    GROUP BY
        turnout.election_id,
        turnout.office_id,
        turnout.territory_id,
        turnout.registered_voters,
        turnout.voters,
        turnout.blank_votes,
        turnout.null_votes
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        registered_voters = EXCLUDED.registered_voters,
        voters = EXCLUDED.voters,
        blank_votes = EXCLUDED.blank_votes,
        null_votes = EXCLUDED.null_votes,
        candidate_votes = EXCLUDED.candidate_votes,
        turnout_rate = EXCLUDED.turnout_rate,
        blank_rate = EXCLUDED.blank_rate,
        null_rate = EXCLUDED.null_rate,
        updated_at = now();

    DELETE FROM op.result_summary summary
    WHERE summary.election_id = p_election_id
      AND summary.office_id = p_office_id
      AND summary.territory_id = p_territory_id
      AND NOT EXISTS (
          SELECT 1
          FROM op.turnout_result turnout
          WHERE turnout.election_id = summary.election_id
            AND turnout.office_id = summary.office_id
            AND turnout.territory_id = summary.territory_id
      );
END;
$$;


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

DROP TRIGGER IF EXISTS turnout_refresh_summary_after_write ON op.turnout_result;
DROP TRIGGER IF EXISTS turnout_result_refresh_summary ON op.turnout_result;

CREATE TRIGGER turnout_result_refresh_summary
AFTER INSERT OR UPDATE OR DELETE ON op.turnout_result
FOR EACH ROW
EXECUTE FUNCTION op.refresh_result_summary_after_change();

DROP TRIGGER IF EXISTS vote_refresh_summary_after_write ON op.vote_result;
DROP TRIGGER IF EXISTS vote_result_refresh_summary ON op.vote_result;

CREATE TRIGGER vote_result_refresh_summary
AFTER INSERT OR UPDATE OR DELETE ON op.vote_result
FOR EACH ROW
EXECUTE FUNCTION op.refresh_result_summary_after_change();


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


CREATE OR REPLACE FUNCTION op.save_turnout_result(
    p_election_code text,
    p_office_code text,
    p_territory_code text,
    p_registered_voters int,
    p_voters int,
    p_blank_votes int,
    p_null_votes int,
    p_import_file_id bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    selected_election_id bigint;
    selected_office_id bigint;
    selected_territory_id bigint;
BEGIN
    SELECT election_id
    INTO selected_election_id
    FROM op.election
    WHERE code = p_election_code;

    SELECT office_id
    INTO selected_office_id
    FROM op.office
    WHERE code = p_office_code;

    SELECT territory_id
    INTO selected_territory_id
    FROM op.territory
    WHERE code = p_territory_code;

    IF selected_election_id IS NULL THEN
        RAISE EXCEPTION 'unknown election code %', p_election_code;
    END IF;

    IF selected_office_id IS NULL THEN
        RAISE EXCEPTION 'unknown office code %', p_office_code;
    END IF;

    IF selected_territory_id IS NULL THEN
        RAISE EXCEPTION 'unknown territory code %', p_territory_code;
    END IF;

    INSERT INTO op.turnout_result (
        election_id,
        office_id,
        territory_id,
        registered_voters,
        voters,
        blank_votes,
        null_votes,
        import_file_id
    )
    VALUES (
        selected_election_id,
        selected_office_id,
        selected_territory_id,
        COALESCE(p_registered_voters, 0),
        COALESCE(p_voters, 0),
        COALESCE(p_blank_votes, 0),
        COALESCE(p_null_votes, 0),
        p_import_file_id
    )
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        registered_voters = EXCLUDED.registered_voters,
        voters = EXCLUDED.voters,
        blank_votes = EXCLUDED.blank_votes,
        null_votes = EXCLUDED.null_votes,
        import_file_id = EXCLUDED.import_file_id,
        updated_at = now();
END;
$$;


CREATE OR REPLACE FUNCTION op.save_candidacy_vote_result(
    p_election_code text,
    p_office_code text,
    p_territory_code text,
    p_sigla text,
    p_entity_type text,
    p_votes int,
    p_display_order int DEFAULT NULL,
    p_import_file_id bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    selected_election_id bigint;
    selected_office_id bigint;
    selected_territory_id bigint;
    selected_entity_id bigint;
    saved_candidacy_id bigint;
BEGIN
    SELECT election_id
    INTO selected_election_id
    FROM op.election
    WHERE code = p_election_code;

    SELECT office_id
    INTO selected_office_id
    FROM op.office
    WHERE code = p_office_code;

    SELECT territory_id
    INTO selected_territory_id
    FROM op.territory
    WHERE code = p_territory_code;

    IF selected_election_id IS NULL THEN
        RAISE EXCEPTION 'unknown election code %', p_election_code;
    END IF;

    IF selected_office_id IS NULL THEN
        RAISE EXCEPTION 'unknown office code %', p_office_code;
    END IF;

    IF selected_territory_id IS NULL THEN
        RAISE EXCEPTION 'unknown territory code %', p_territory_code;
    END IF;

    selected_entity_id := op.save_political_entity(
        p_sigla,
        p_entity_type
    );

    INSERT INTO op.candidacy (
        election_id,
        office_id,
        territory_id,
        political_entity_id,
        display_order,
        source_label
    )
    VALUES (
        selected_election_id,
        selected_office_id,
        selected_territory_id,
        selected_entity_id,
        p_display_order,
        p_sigla
    )
    ON CONFLICT (election_id, office_id, territory_id, political_entity_id)
    DO UPDATE SET
        display_order = COALESCE(EXCLUDED.display_order, op.candidacy.display_order),
        source_label = EXCLUDED.source_label
    RETURNING candidacy_id
    INTO saved_candidacy_id;

    INSERT INTO op.vote_result (
        election_id,
        office_id,
        territory_id,
        candidacy_id,
        votes,
        import_file_id
    )
    VALUES (
        selected_election_id,
        selected_office_id,
        selected_territory_id,
        saved_candidacy_id,
        COALESCE(p_votes, 0),
        p_import_file_id
    )
    ON CONFLICT (election_id, office_id, territory_id, candidacy_id)
    DO UPDATE SET
        votes = EXCLUDED.votes,
        import_file_id = EXCLUDED.import_file_id,
        updated_at = now();
END;
$$;
