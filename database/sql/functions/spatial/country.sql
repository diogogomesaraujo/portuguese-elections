CREATE OR REPLACE FUNCTION country(
    election_type text,
    election_year integer,
    office text,
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
        'district',
        NULL,
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
STABLE;
