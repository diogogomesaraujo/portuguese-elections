CREATE SCHEMA IF NOT EXISTS wh;

DROP TABLE IF EXISTS wh.fact_vote_result CASCADE;
DROP TABLE IF EXISTS wh.fact_turnout CASCADE;
DROP TABLE IF EXISTS wh.dim_political_entity CASCADE;
DROP TABLE IF EXISTS wh.dim_territory CASCADE;
DROP TABLE IF EXISTS wh.dim_office CASCADE;
DROP TABLE IF EXISTS wh.dim_election CASCADE;

CREATE TABLE wh.dim_election AS
SELECT
    e.election_id AS election_key,
    e.code AS election_code,
    et.code AS election_type,
    e.name AS election_name,
    e.election_year,
    e.election_date
FROM op.election e
JOIN op.election_type et ON et.election_type_id = e.election_type_id;

ALTER TABLE wh.dim_election ADD PRIMARY KEY (election_key);

CREATE TABLE wh.dim_office AS
SELECT
    office_id AS office_key,
    code AS office_code,
    name AS office_name,
    scope_level
FROM op.office;

ALTER TABLE wh.dim_office ADD PRIMARY KEY (office_key);

CREATE TABLE wh.dim_territory AS
SELECT
    t.territory_id AS territory_key,
    t.code AS territory_code,
    t.name AS territory_name,
    tl.code AS territory_level,
    p.code AS parent_code,
    p.name AS parent_name,
    t.geom
FROM op.territory t
JOIN op.territory_level tl ON tl.territory_level_id = t.level_id
LEFT JOIN op.territory p ON p.territory_id = t.parent_id;

ALTER TABLE wh.dim_territory ADD PRIMARY KEY (territory_key);

CREATE INDEX IF NOT EXISTS wh_dim_territory_code_idx
ON wh.dim_territory(territory_code);

CREATE INDEX IF NOT EXISTS wh_dim_territory_level_idx
ON wh.dim_territory(territory_level);

CREATE INDEX IF NOT EXISTS wh_dim_territory_geom_gix
ON wh.dim_territory USING gist(geom);

CREATE TABLE wh.dim_political_entity AS
SELECT
    political_entity_id AS political_entity_key,
    sigla,
    name,
    entity_type
FROM op.political_entity;

ALTER TABLE wh.dim_political_entity ADD PRIMARY KEY (political_entity_key);

CREATE TABLE wh.fact_turnout AS
SELECT
    tr.election_id AS election_key,
    tr.office_id AS office_key,
    tr.territory_id AS territory_key,
    tr.registered_voters,
    tr.voters,
    tr.blank_votes,
    tr.null_votes,
    rs.candidate_votes,
    rs.turnout_rate,
    rs.blank_rate,
    rs.null_rate
FROM op.turnout_result tr
LEFT JOIN op.result_summary rs
  ON rs.election_id = tr.election_id
 AND rs.office_id = tr.office_id
 AND rs.territory_id = tr.territory_id;

ALTER TABLE wh.fact_turnout
ADD PRIMARY KEY (election_key, office_key, territory_key);

CREATE INDEX IF NOT EXISTS wh_fact_turnout_territory_idx
ON wh.fact_turnout(territory_key);

CREATE TABLE wh.fact_vote_result AS
SELECT
    vr.election_id AS election_key,
    vr.office_id AS office_key,
    vr.territory_id AS territory_key,
    c.political_entity_id AS political_entity_key,
    vr.votes,
    CASE
        WHEN rs.candidate_votes > 0
        THEN round(vr.votes::numeric / rs.candidate_votes, 6)
    END AS vote_share,
    rank() OVER (
        PARTITION BY vr.election_id, vr.office_id, vr.territory_id
        ORDER BY vr.votes DESC
    ) AS result_rank
FROM op.vote_result vr
JOIN op.candidacy c ON c.candidacy_id = vr.candidacy_id
LEFT JOIN op.result_summary rs
  ON rs.election_id = vr.election_id
 AND rs.office_id = vr.office_id
 AND rs.territory_id = vr.territory_id;

ALTER TABLE wh.fact_vote_result
ADD PRIMARY KEY (election_key, office_key, territory_key, political_entity_key);

CREATE INDEX IF NOT EXISTS wh_fact_vote_result_territory_idx
ON wh.fact_vote_result(territory_key);

CREATE INDEX IF NOT EXISTS wh_fact_vote_result_entity_idx
ON wh.fact_vote_result(political_entity_key);

CREATE OR REPLACE PROCEDURE wh.refresh_wh()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE
        wh.fact_vote_result,
        wh.fact_turnout,
        wh.dim_political_entity,
        wh.dim_territory,
        wh.dim_office,
        wh.dim_election;

    INSERT INTO wh.dim_election
    SELECT
        e.election_id,
        e.code,
        et.code,
        e.name,
        e.election_year,
        e.election_date
    FROM op.election e
    JOIN op.election_type et ON et.election_type_id = e.election_type_id;

    INSERT INTO wh.dim_office
    SELECT
        office_id,
        code,
        name,
        scope_level
    FROM op.office;

    INSERT INTO wh.dim_territory
    SELECT
        t.territory_id,
        t.code,
        t.name,
        tl.code,
        p.code,
        p.name,
        t.geom
    FROM op.territory t
    JOIN op.territory_level tl ON tl.territory_level_id = t.level_id
    LEFT JOIN op.territory p ON p.territory_id = t.parent_id;

    INSERT INTO wh.dim_political_entity
    SELECT
        political_entity_id,
        sigla,
        name,
        entity_type
    FROM op.political_entity;

    INSERT INTO wh.fact_turnout
    SELECT
        tr.election_id,
        tr.office_id,
        tr.territory_id,
        tr.registered_voters,
        tr.voters,
        tr.blank_votes,
        tr.null_votes,
        rs.candidate_votes,
        rs.turnout_rate,
        rs.blank_rate,
        rs.null_rate
    FROM op.turnout_result tr
    LEFT JOIN op.result_summary rs
      ON rs.election_id = tr.election_id
     AND rs.office_id = tr.office_id
     AND rs.territory_id = tr.territory_id;

    INSERT INTO wh.fact_vote_result
    SELECT
        vr.election_id,
        vr.office_id,
        vr.territory_id,
        c.political_entity_id,
        vr.votes,
        CASE
            WHEN rs.candidate_votes > 0
            THEN round(vr.votes::numeric / rs.candidate_votes, 6)
        END AS vote_share,
        rank() OVER (
            PARTITION BY vr.election_id, vr.office_id, vr.territory_id
            ORDER BY vr.votes DESC
        ) AS result_rank
    FROM op.vote_result vr
    JOIN op.candidacy c ON c.candidacy_id = vr.candidacy_id
    LEFT JOIN op.result_summary rs
      ON rs.election_id = vr.election_id
     AND rs.office_id = vr.office_id
     AND rs.territory_id = vr.territory_id;
END;
$$;
