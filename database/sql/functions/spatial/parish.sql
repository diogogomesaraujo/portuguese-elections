CREATE OR REPLACE FUNCTION parish(
    election_type text,
    election_year integer,
    office text,
    parish_name text,
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
        NULL,
        parish_name,
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
STABLE;
