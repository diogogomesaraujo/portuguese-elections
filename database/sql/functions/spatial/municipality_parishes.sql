CREATE OR REPLACE FUNCTION municipality_parishes(
    election_type text,
    election_year integer,
    office text,
    municipality_name text,
    party_sigla text,
    stroke text,
    strokewidth text,
    fill text,
    fillopacity text,
    precision_value integer
)
RETURNS text AS
$$
BEGIN
    RETURN map_territory(
        election_type,
        election_year,
        office,
        'parish',
        municipality_name,
        NULL,
        party_sigla,
        stroke,
        strokewidth,
        fill,
        fillopacity,
        precision_value
    );
END;
$$
LANGUAGE plpgsql
IMMUTABLE;
