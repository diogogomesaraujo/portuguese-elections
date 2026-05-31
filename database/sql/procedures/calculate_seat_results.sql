CREATE OR REPLACE PROCEDURE op.calculate_seat_results()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM op.seat_result
    WHERE method = 'dhondt_calculated';

    WITH quotients AS (
        SELECT
            vote.election_id,
            vote.office_id,
            vote.territory_id,
            vote.candidacy_id,
            vote.votes,
            divisor.n AS divisor,
            vote.votes::numeric / divisor.n AS quotient
        FROM op.vote_result vote
        JOIN op.seat_count seat_count
          ON seat_count.election_id = vote.election_id
         AND seat_count.office_id = vote.office_id
         AND seat_count.territory_id = vote.territory_id
        CROSS JOIN LATERAL generate_series(1, seat_count.seats) AS divisor(n)
        WHERE vote.votes > 0
          AND NOT EXISTS (
              SELECT 1
              FROM op.seat_result official
              WHERE official.election_id = vote.election_id
                AND official.office_id = vote.office_id
                AND official.territory_id = vote.territory_id
                AND official.method = 'official'
          )
    ),

    ranked AS (
        SELECT
            quotients.*,
            row_number() OVER (
                PARTITION BY election_id, office_id, territory_id
                ORDER BY quotient DESC, votes DESC, candidacy_id
            ) AS quotient_rank
        FROM quotients
    ),

    allocated AS (
        SELECT
            ranked.election_id,
            ranked.office_id,
            ranked.territory_id,
            ranked.candidacy_id,
            COUNT(*)::int AS seats
        FROM ranked
        JOIN op.seat_count seat_count
          ON seat_count.election_id = ranked.election_id
         AND seat_count.office_id = ranked.office_id
         AND seat_count.territory_id = ranked.territory_id
        WHERE ranked.quotient_rank <= seat_count.seats
        GROUP BY
            ranked.election_id,
            ranked.office_id,
            ranked.territory_id,
            ranked.candidacy_id
    )

    INSERT INTO op.seat_result (
        election_id,
        office_id,
        territory_id,
        candidacy_id,
        seats,
        method,
        updated_at
    )
    SELECT
        election_id,
        office_id,
        territory_id,
        candidacy_id,
        seats,
        'dhondt_calculated',
        now()
    FROM allocated
    ON CONFLICT (election_id, office_id, territory_id, candidacy_id)
    DO UPDATE SET
        seats = EXCLUDED.seats,
        method = EXCLUDED.method,
        updated_at = now()
    WHERE op.seat_result.method = 'dhondt_calculated';
END;
$$;
