CREATE OR REPLACE FUNCTION district_municipalities(
    election_type text,
    election_year integer,
    office text,
    district_name text,
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
        'municipality',
        district_name,
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
