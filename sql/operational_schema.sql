CREATE SCHEMA IF NOT EXISTS op;

CREATE TABLE IF NOT EXISTS op.election_type (
    election_type_id bigserial PRIMARY KEY,
    code text NOT NULL UNIQUE,              -- AUTARQUICAS, LEGISLATIVAS, EUROPEIAS, PRESIDENCIAIS
    name text NOT NULL
);

CREATE TABLE IF NOT EXISTS op.election (
    election_id bigserial PRIMARY KEY,
    election_type_id bigint NOT NULL REFERENCES op.election_type(election_type_id),
    code text NOT NULL UNIQUE,              -- AUTARQUICAS_2021, LEGISLATIVAS_2024
    name text NOT NULL,
    election_date date,
    election_year int NOT NULL CHECK (election_year BETWEEN 1900 AND 2200),
    source_name text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (election_type_id, election_year)
);

CREATE TABLE IF NOT EXISTS op.office (
    office_id bigserial PRIMARY KEY,
    code text NOT NULL UNIQUE,              -- CM, AM, AF, AR, PR, PE
    name text NOT NULL,
    scope_level text NOT NULL CHECK (scope_level IN ('country','district','municipality','parish'))
);

CREATE TABLE IF NOT EXISTS op.territory_level (
    territory_level_id smallserial PRIMARY KEY,
    code text NOT NULL UNIQUE CHECK (code IN ('country','district','municipality','parish')),
    name text NOT NULL,
    depth smallint NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS op.territory (
    territory_id bigserial PRIMARY KEY,
    level_id smallint NOT NULL REFERENCES op.territory_level(territory_level_id),
    code text NOT NULL UNIQUE,              -- PT, 01, 0101, 010103
    name text NOT NULL,
    parent_id bigint REFERENCES op.territory(territory_id),
    normalized_name text,
    geom geometry(MultiPolygon,4326),       -- always WGS84 for frontend/Leaflet
    source_table text,
    source_srid int,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (code <> '')
);

CREATE INDEX IF NOT EXISTS territory_parent_idx ON op.territory(parent_id);
CREATE INDEX IF NOT EXISTS territory_level_idx ON op.territory(level_id);
CREATE INDEX IF NOT EXISTS territory_name_trgm_idx ON op.territory USING gin (normalized_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS territory_geom_gix ON op.territory USING gist (geom);

CREATE TABLE IF NOT EXISTS op.political_entity (
    political_entity_id bigserial PRIMARY KEY,
    sigla text NOT NULL UNIQUE,             -- PS, PPD/PSD, PCP-PEV, PPD/PSD.MPT, M.A.
    name text,
    entity_type text NOT NULL CHECK (entity_type IN ('party','coalition','gce','blank','null','other')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS op.political_entity_member (
    coalition_id bigint NOT NULL REFERENCES op.political_entity(political_entity_id) ON DELETE CASCADE,
    member_id bigint NOT NULL REFERENCES op.political_entity(political_entity_id) ON DELETE RESTRICT,
    PRIMARY KEY (coalition_id, member_id),
    CHECK (coalition_id <> member_id)
);

CREATE TABLE IF NOT EXISTS op.candidacy (
    candidacy_id bigserial PRIMARY KEY,
    election_id bigint NOT NULL REFERENCES op.election(election_id) ON DELETE CASCADE,
    office_id bigint NOT NULL REFERENCES op.office(office_id),
    territory_id bigint NOT NULL REFERENCES op.territory(territory_id),
    political_entity_id bigint NOT NULL REFERENCES op.political_entity(political_entity_id),
    display_order int,
    source_label text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (election_id, office_id, territory_id, political_entity_id)
);

CREATE TABLE IF NOT EXISTS op.import_file (
    import_file_id bigserial PRIMARY KEY,
    election_id bigint NOT NULL REFERENCES op.election(election_id) ON DELETE CASCADE,
    file_path text NOT NULL,
    sheet_name text NOT NULL,
    file_hash text NOT NULL,
    imported_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (election_id, file_hash, sheet_name)
);

CREATE TABLE IF NOT EXISTS op.turnout_result (
    election_id bigint NOT NULL REFERENCES op.election(election_id) ON DELETE CASCADE,
    office_id bigint NOT NULL REFERENCES op.office(office_id),
    territory_id bigint NOT NULL REFERENCES op.territory(territory_id),
    registered_voters int NOT NULL CHECK (registered_voters >= 0),
    voters int NOT NULL CHECK (voters >= 0),
    blank_votes int NOT NULL CHECK (blank_votes >= 0),
    null_votes int NOT NULL CHECK (null_votes >= 0),
    import_file_id bigint REFERENCES op.import_file(import_file_id),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (election_id, office_id, territory_id)
);

CREATE TABLE IF NOT EXISTS op.vote_result (
    election_id bigint NOT NULL REFERENCES op.election(election_id) ON DELETE CASCADE,
    office_id bigint NOT NULL REFERENCES op.office(office_id),
    territory_id bigint NOT NULL REFERENCES op.territory(territory_id),
    candidacy_id bigint NOT NULL REFERENCES op.candidacy(candidacy_id) ON DELETE CASCADE,
    votes int NOT NULL CHECK (votes >= 0),
    import_file_id bigint REFERENCES op.import_file(import_file_id),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (election_id, office_id, territory_id, candidacy_id)
);

CREATE INDEX IF NOT EXISTS vote_result_lookup_idx ON op.vote_result(election_id, office_id, territory_id, votes DESC);
CREATE INDEX IF NOT EXISTS vote_result_candidacy_idx ON op.vote_result(candidacy_id);

CREATE TABLE IF NOT EXISTS op.seat_result (
    election_id bigint NOT NULL REFERENCES op.election(election_id) ON DELETE CASCADE,
    office_id bigint NOT NULL REFERENCES op.office(office_id),
    territory_id bigint NOT NULL REFERENCES op.territory(territory_id),
    candidacy_id bigint NOT NULL REFERENCES op.candidacy(candidacy_id) ON DELETE CASCADE,
    seats int NOT NULL CHECK (seats >= 0),
    method text NOT NULL DEFAULT 'official',
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (election_id, office_id, territory_id, candidacy_id)
);

CREATE TABLE IF NOT EXISTS op.result_summary (
    election_id bigint NOT NULL REFERENCES op.election(election_id) ON DELETE CASCADE,
    office_id bigint NOT NULL REFERENCES op.office(office_id),
    territory_id bigint NOT NULL REFERENCES op.territory(territory_id),
    registered_voters int NOT NULL DEFAULT 0,
    voters int NOT NULL DEFAULT 0,
    blank_votes int NOT NULL DEFAULT 0,
    null_votes int NOT NULL DEFAULT 0,
    candidate_votes int NOT NULL DEFAULT 0,
    turnout_rate numeric(10,6),
    blank_rate numeric(10,6),
    null_rate numeric(10,6),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (election_id, office_id, territory_id)
);
