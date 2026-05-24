-- Creates a new party

CREATE OR REPLACE PROCEDURE add_party(new_acronym TEXT, new_full_name TEXT)
LANGUAGE plpgsql
AS
$$
BEGIN
    INSERT INTO parties (acronym, full_name)
    VALUES (new_acronym, new_full_name);
END;
$$;


-- Example

CALL add_party('TEST', 'Test Party');


-- Compute the turnout of a district

CREATE OR REPLACE FUNCTION calculate_turnout(district_name TEXT)
RETURNS NUMERIC
AS
$$
DECLARE
    turnout NUMERIC;
BEGIN
    SELECT
        ROUND((p.voters::numeric / p.registered_voters) * 100, 2)
    INTO turnout
    FROM participation p
    JOIN districts d ON p.district_id = d.district_id
    WHERE d.name = district_name;
    RETURN turnout;
END;
$$ 
LANGUAGE plpgsql;


-- Example

SELECT calculate_turnout('Porto');


-- Measures if people in each district tend to vote to few or many parties

CREATE OR REPLACE FUNCTION district_fragmentation(district_name TEXT)
RETURNS TABLE (
    district TEXT,
    parties_with_mandates INTEGER,
    total_mandates BIGINT,
    fragmentation_ratio NUMERIC,
    fragmentation_level TEXT
)
AS
$$
DECLARE
    party_count INTEGER;
	mandates_count BIGINT;
    ratio NUMERIC;
BEGIN
    SELECT
        COUNT(*),
        SUM(r.mandates)
    INTO
        party_count, mandates_count
    FROM results r
    JOIN districts d ON r.district_id = d.district_id
    WHERE d.name = district_name
    AND r.mandates > 0;
    ratio := ROUND(party_count::numeric / mandates_count, 2);
    RETURN QUERY
    SELECT
        district_name, party_count, mandates_count, ratio,
        CASE
            WHEN ratio >= 0.30
            THEN 'High Fragmentation'

            WHEN ratio >= 0.15
            THEN 'Medium Fragmentation'

            ELSE 'Low Fragmentation'
        END;
END;
$$ 
LANGUAGE plpgsql;


-- Example

SELECT *
FROM district_fragmentation('Lisboa');


-- Computes the D'Hondt function to select to which parties corresponds each mandate

CREATE OR REPLACE FUNCTION calculate_dhondt(district_name TEXT)
RETURNS TABLE (
    district TEXT,
    party TEXT,
    votes BIGINT,
    divisor INTEGER,
    quotient NUMERIC,
    seat_rank BIGINT
)
AS
$$
BEGIN
    RETURN QUERY
    WITH divisors AS (
        SELECT generate_series(1, 50) AS divisor
    ),
    district_seats AS (
        SELECT
            SUM(r.mandates) AS total_seats
        FROM results r
        JOIN districts d ON r.district_id = d.district_id
        WHERE d.name = district_name
    ),
    dhondt AS (
        SELECT
            d.name AS district, p.acronym AS party, r.votes, divisors.divisor,
            ROUND(r.votes::numeric / divisors.divisor, 2) AS quotient
        FROM results r
        JOIN parties p ON r.party_id = p.party_id
        JOIN districts d ON r.district_id = d.district_id
        CROSS JOIN divisors
        WHERE d.name = district_name
    ),
    ranked AS (
        SELECT
            dhondt.district, dhondt.party, dhondt.votes, 
			dhondt.divisor, dhondt.quotient,
            RANK() OVER (
                ORDER BY dhondt.quotient DESC
            ) AS seat_rank
        FROM dhondt
    )
    SELECT
        ranked.district, ranked.party, ranked.votes, 
		ranked.divisor, ranked.quotient, ranked.seat_rank
    FROM ranked
    WHERE ranked.seat_rank <= (
        SELECT total_seats
        FROM district_seats
    )
    ORDER BY ranked.seat_rank;
END;
$$ 
LANGUAGE plpgsql;


SELECT *
FROM calculate_dhondt('Porto');