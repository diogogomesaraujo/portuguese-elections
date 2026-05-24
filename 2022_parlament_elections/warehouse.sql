CREATE TABLE warehouse.dim_districts (

    district_id INTEGER PRIMARY KEY,

    district_name TEXT
);

INSERT INTO warehouse.dim_districts

SELECT
    district_id,
    name

FROM districts;

CREATE TABLE warehouse.dim_parties (

    party_id INTEGER PRIMARY KEY,

    acronym TEXT
);

INSERT INTO warehouse.dim_parties

SELECT
    party_id,
    acronym

FROM parties;

CREATE TABLE warehouse.dim_elections (

    election_id INTEGER PRIMARY KEY,

    election_year INTEGER
);

INSERT INTO warehouse.dim_elections

VALUES (
    1,
    2022
);

CREATE TABLE warehouse.fact_results (

    election_id INTEGER,

    district_id INTEGER,

    party_id INTEGER,

    votes BIGINT,

    mandates INTEGER,

    vote_percentage NUMERIC(5,2)
);

INSERT INTO warehouse.fact_results

SELECT
    election_id,
    district_id,
    party_id,
    votes,
    mandates,
    vote_percentage

FROM results;