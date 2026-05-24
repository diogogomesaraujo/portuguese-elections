-- Party with the most votes in each district

SELECT
    d.name AS district, p.acronym AS party, r.votes
FROM results r
JOIN districts d ON r.district_id = d.district_id
JOIN parties p ON r.party_id = p.party_id
WHERE r.votes = (
    SELECT MAX(r2.votes)
    FROM results r2
    WHERE r2.district_id = r.district_id
);


-- Votes for each party in Porto

SELECT
    p.acronym, SUM(r.votes) AS total_votes
FROM results r
JOIN parties p ON r.party_id = p.party_id
JOIN districts d ON r.district_id = d.district_id
WHERE d.name = 'Porto'
GROUP BY p.acronym
ORDER BY total_votes DESC;


-- % of voters in each district

SELECT
    d.name AS district,
    p.registered_voters,
    p.voters,
    ROUND((p.voters::numeric / p.registered_voters) * 100, 2) AS participation_rate
FROM participation p
JOIN districts d ON p.district_id = d.district_id
ORDER BY participation_rate DESC;


-- Difference between votes of the 2 most voted parties in each district

WITH ranked AS (
    SELECT
        d.name AS district, p.acronym AS party, r.votes,
        RANK() OVER (
            PARTITION BY d.name
            ORDER BY r.votes DESC
        ) 
		AS ranking
    FROM results r
    JOIN districts d ON r.district_id = d.district_id
    JOIN parties p ON r.party_id = p.party_id
)
SELECT
    r1.district,
    r1.party AS winner,
    r1.votes AS winner_votes,
    r2.party AS second_place,
    r2.votes AS second_votes,
    r1.votes - r2.votes AS difference
FROM ranked r1
JOIN ranked r2 ON r1.district = r2.district
WHERE r1.ranking = 1
AND r2.ranking = 2
ORDER BY difference DESC;


-- Ranks each district by number of votes using group by rollup

SELECT
    COALESCE(d.name, 'National Total') AS district,
    SUM(r.votes) AS total_votes
FROM results r
JOIN districts d ON r.district_id = d.district_id
GROUP BY ROLLUP(d.name)
ORDER BY total_votes DESC;


-- Computes the total votes by district and party using group by cube

SELECT
    COALESCE(d.name, 'All Districts') AS district,
    COALESCE(p.acronym, 'All Parties') AS party,
    SUM(r.votes) AS total_votes
FROM results r
JOIN districts d ON r.district_id = d.district_id
JOIN parties p ON r.party_id = p.party_id
GROUP BY CUBE(d.name, p.acronym)
ORDER BY district, total_votes DESC;


-- Ranks the districts by participation_rate

SELECT
    d.name AS district,
    ROUND((p.voters::numeric / p.registered_voters) * 100, 2) AS participation_rate,
    RANK() OVER (
        ORDER BY
        (p.voters::numeric / p.registered_voters) DESC
    ) 
	AS participation_rank
FROM participation p
JOIN districts d ON p.district_id = d.district_id;


-- Shows the parties with at least 1 mandate in each district using String_Agg

SELECT
    d.name, STRING_AGG(p.acronym, ', ') AS represented_parties
FROM results r
JOIN districts d ON r.district_id = d.district_id
JOIN parties p ON r.party_id = p.party_id
WHERE r.mandates > 0
GROUP BY d.name;


-- Query that uses the D'Hondt method

WITH divisors AS (
    SELECT generate_series(1, 50) AS divisor
),
district_seats AS (
    SELECT
        SUM(r.mandates) AS total_seats
    FROM results r
    JOIN districts d ON r.district_id = d.district_id
    WHERE d.name = 'Porto'
),
dhondt AS (
    SELECT
        d.name AS district, p.acronym AS party, r.votes, divisors.divisor,
        ROUND(r.votes::numeric / divisors.divisor, 2) AS quotient
    FROM results r
    JOIN parties p ON r.party_id = p.party_id
    JOIN districts d ON r.district_id = d.district_id
    CROSS JOIN divisors
    WHERE d.name = 'Porto'
),
ranked AS (
    SELECT
        district, party, votes, divisor, quotient,
        RANK() OVER (
            ORDER BY quotient DESC
        ) 
		AS seat_rank
    FROM dhondt
)
SELECT
    district, party, votes, divisor, quotient, seat_rank
FROM ranked
WHERE seat_rank <= (
    SELECT total_seats
    FROM district_seats
)
ORDER BY seat_rank;