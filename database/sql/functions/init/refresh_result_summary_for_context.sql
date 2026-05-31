CREATE OR REPLACE FUNCTION op.refresh_result_summary_for_context(
    p_election_id bigint,
    p_office_id bigint,
    p_territory_id bigint
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO op.result_summary (
        election_id,
        office_id,
        territory_id,
        registered_voters,
        voters,
        blank_votes,
        null_votes,
        candidate_votes,
        total_seats,
        turnout_rate,
        blank_rate,
        null_rate,
        updated_at
    )
    SELECT
        turnout.election_id,
        turnout.office_id,
        turnout.territory_id,
        turnout.registered_voters,
        turnout.voters,
        turnout.blank_votes,
        turnout.null_votes,
        COALESCE(SUM(vote.votes), 0)::int AS candidate_votes,
        COALESCE(seat_count.seats, 0) AS total_seats,
        CASE
            WHEN turnout.registered_voters > 0
            THEN round(turnout.voters::numeric / turnout.registered_voters, 6)
        END AS turnout_rate,
        CASE
            WHEN turnout.voters > 0
            THEN round(turnout.blank_votes::numeric / turnout.voters, 6)
        END AS blank_rate,
        CASE
            WHEN turnout.voters > 0
            THEN round(turnout.null_votes::numeric / turnout.voters, 6)
        END AS null_rate,
        now()
    FROM op.turnout_result turnout
    LEFT JOIN op.vote_result vote
    ON vote.election_id = turnout.election_id
    AND vote.office_id = turnout.office_id
    AND vote.territory_id = turnout.territory_id
    LEFT JOIN op.seat_count seat_count
    ON seat_count.election_id = turnout.election_id
    AND seat_count.office_id = turnout.office_id
    AND seat_count.territory_id = turnout.territory_id
    WHERE turnout.election_id = p_election_id
    AND turnout.office_id = p_office_id
    AND turnout.territory_id = p_territory_id
    GROUP BY
        turnout.election_id,
        turnout.office_id,
        turnout.territory_id,
        turnout.registered_voters,
        turnout.voters,
        turnout.blank_votes,
        turnout.null_votes,
        seat_count.seats
    ON CONFLICT (election_id, office_id, territory_id)
    DO UPDATE SET
        registered_voters = EXCLUDED.registered_voters,
        voters = EXCLUDED.voters,
        blank_votes = EXCLUDED.blank_votes,
        null_votes = EXCLUDED.null_votes,
        candidate_votes = EXCLUDED.candidate_votes,
        turnout_rate = EXCLUDED.turnout_rate,
        blank_rate = EXCLUDED.blank_rate,
        null_rate = EXCLUDED.null_rate,
        total_seats = EXCLUDED.total_seats,
        updated_at = now();

    DELETE FROM op.result_summary summary
    WHERE summary.election_id = p_election_id
      AND summary.office_id = p_office_id
      AND summary.territory_id = p_territory_id
      AND NOT EXISTS (
          SELECT 1
          FROM op.turnout_result turnout
          WHERE turnout.election_id = summary.election_id
            AND turnout.office_id = summary.office_id
            AND turnout.territory_id = summary.territory_id
      );
END;
$$;
