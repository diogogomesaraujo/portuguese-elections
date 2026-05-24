CREATE TABLE offices (

    office_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT
);

CREATE TABLE coalitions (

    coalition_id SERIAL PRIMARY KEY,
    acronym TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL
);


CREATE TABLE candidacies (

    candidacy_id SERIAL PRIMARY KEY,
    election_id INT NOT NULL,
    district_id INT NOT NULL,
    party_id INT,
    coalition_id INT,
    candidate_name TEXT
);


CREATE TABLE elections (

    election_id SERIAL PRIMARY KEY,
    year INTEGER NOT NULL,
    type TEXT NOT NULL
);


CREATE TABLE districts (

    district_id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);


CREATE TABLE parties (

    party_id SERIAL PRIMARY KEY,
    acronym TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL
);


CREATE TABLE participation (

    participation_id SERIAL PRIMARY KEY,
    election_id INTEGER REFERENCES elections(election_id),
    district_id INTEGER REFERENCES districts(district_id),
    registered_voters INTEGER,
    voters INTEGER,
    abstention_percentage NUMERIC(5,2),
    blank_votes INTEGER,
    null_votes INTEGER,
    valid_votes INTEGER
);


CREATE TABLE results (

    result_id SERIAL PRIMARY KEY,
    election_id INTEGER REFERENCES elections(election_id),
    district_id INTEGER REFERENCES districts(district_id),
    party_id INTEGER REFERENCES parties(party_id),
    votes BIGINT,
    vote_percentage DOUBLE PRECISION,
    mandates INTEGER
);


CREATE TABLE staging.raw_results (

    district TEXT,
    registered_voters TEXT,
    voters TEXT,
    abstencion_percentage TEXT,
    blank_votes TEXT,
    null_votes TEXT,
    valid_votes TEXT,
    party TEXT,
    votes TEXT,
    vote_percentage TEXT,
    mandates TEXT
);