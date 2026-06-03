CREATE SCHEMA IF NOT EXISTS wh;

DROP FUNCTION IF EXISTS wh.results_for_territory_parties(
    text,
    integer,
    text,
    text
);

DROP FUNCTION IF EXISTS wh.results_for_territory_parties(
    text,
    integer,
    text,
    text,
    text
);

DROP FUNCTION IF EXISTS wh.results_for_territory_parties(
    text,
    integer,
    text,
    bigint
);

CREATE OR REPLACE FUNCTION op.normalized_sigla(p_sigla text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN upper(regexp_replace(COALESCE(p_sigla, ''), '\s+', '', 'g')) IN ('BE', 'B.E')
            THEN 'B.E.'
        WHEN upper(regexp_replace(COALESCE(p_sigla, ''), '\s+', '', 'g')) IN ('RIR', 'R.I.R')
            THEN 'R.I.R.'
        WHEN upper(regexp_replace(COALESCE(p_sigla, ''), '\s+', '', 'g')) IN ('VOLT', 'VOLT.')
            THEN 'VP'
        ELSE replace(
            upper(regexp_replace(COALESCE(p_sigla, ''), '\s+', '', 'g')),
            'PPD/PDS',
            'PPD/PSD'
        )
    END;
$$;

CREATE OR REPLACE FUNCTION op.known_political_party_order()
RETURNS TABLE (
    member_sigla text,
    member_order numeric,
    match_pattern text
)
LANGUAGE sql
IMMUTABLE
AS $$
    VALUES
        ('PCP-PEV', 10::numeric, '(^|[.+/\-])(PCP-PEV|CDU)($|[.+/\-])'),
        ('PCTP/MRPP', 15::numeric, '(^|[.+/\-])PCTP/MRPP($|[.+/\-])'),
        ('MAS', 18::numeric, '(^|[.+/\-])MAS($|[.+/\-])'),

        /*
          Left.
        */
        ('B.E.', 20::numeric, '(^|[.+/\-])(B\.E\.|BE)($|[.+/\-])'),
        ('L', 30::numeric, '(^|[.+/\-])L($|[.+/\-])'),
        ('PAN', 35::numeric, '(^|[.+/\-])PAN($|[.+/\-])'),

        /*
          Center-left.
        */
        ('PS', 40::numeric, '(^|[.+/\-])PS($|[.+/\-])'),
        ('PTP', 42::numeric, '(^|[.+/\-])PTP($|[.+/\-])'),
        ('PURP', 43::numeric, '(^|[.+/\-])PURP($|[.+/\-])'),
        ('JPP', 45::numeric, '(^|[.+/\-])JPP($|[.+/\-])'),
        ('MPT', 50::numeric, '(^|[.+/\-])MPT($|[.+/\-])'),
        ('PDR', 52::numeric, '(^|[.+/\-])PDR($|[.+/\-])'),
        ('VP', 55::numeric, '(^|[.+/\-])(VP|VOLT)($|[.+/\-])'),
        ('PLS', 57::numeric, '(^|[.+/\-])PLS($|[.+/\-])'),

        /*
          Center / right minor parties.
        */
        ('R.I.R.', 62::numeric, '(^|[.+/\-])(R\.I\.R\.|RIR)($|[.+/\-])'),
        ('ADN', 65::numeric, '(^|[.+/\-])ADN($|[.+/\-])'),
        ('NC', 67::numeric, '(^|[.+/\-])NC($|[.+/\-])'),
        ('ND', 68::numeric, '(^|[.+/\-])ND($|[.+/\-])'),

        /*
          Right.
          Required order:
            PSD < IL < CDS
        */
        ('PPD/PSD', 70::numeric, '(^|[.+\-])(PPD/PSD|PSD)($|[.+/\-])'),
        ('A', 72::numeric, '(^|[.+/\-])A($|[.+/\-])'),
        ('IL', 75::numeric, '(^|[.+/\-])IL($|[.+/\-])'),
        ('CDS-PP', 80::numeric, '(^|[.+/\-])(CDS-PP|CDS/PP|CDS)($|[.+/\-])'),
        ('PPV/CDC', 82::numeric, '(^|[.+/\-])PPV/CDC($|[.+/\-])'),
        ('PPM', 85::numeric, '(^|[.+/\-])PPM($|[.+/\-])'),
        ('PNR', 88::numeric, '(^|[.+/\-])PNR($|[.+/\-])'),
        ('CH', 90::numeric, '(^|[.+/\-])CH($|[.+/\-])'),
        ('E', 92::numeric, '(^|[.+/\-])E($|[.+/\-])')
$$;

CREATE OR REPLACE FUNCTION op.detect_political_entity_members(p_sigla text)
RETURNS TABLE (
    member_sigla text,
    member_order numeric
)
LANGUAGE sql
IMMUTABLE
AS $$
WITH s AS (
    SELECT op.normalized_sigla(p_sigla) AS sigla
),
special_ad AS (
    SELECT 'PPD/PSD'::text AS member_sigla, 70::numeric AS member_order
    FROM s
    WHERE sigla = 'AD'

    UNION ALL

    SELECT 'CDS-PP'::text, 80::numeric
    FROM s
    WHERE sigla = 'AD'

    UNION ALL

    SELECT 'PPM'::text, 85::numeric
    FROM s
    WHERE sigla = 'AD'
),
detected AS (
    SELECT DISTINCT
        k.member_sigla,
        k.member_order
    FROM s
    JOIN op.known_political_party_order() k
      ON s.sigla ~ k.match_pattern
    WHERE s.sigla <> 'AD'
)
SELECT member_sigla, member_order
FROM special_ad

UNION

SELECT member_sigla, member_order
FROM detected
ORDER BY member_order, member_sigla;
$$;

CREATE OR REPLACE FUNCTION op.infer_political_entity_type(
    p_sigla text,
    p_source_entity_type text DEFAULT NULL
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
WITH s AS (
    SELECT op.normalized_sigla(p_sigla) AS sigla
),
known_exact_party AS (
    SELECT member_sigla
    FROM op.known_political_party_order()
    WHERE member_sigla NOT IN ('PCP-PEV')
),
member_count AS (
    SELECT COUNT(*) AS n
    FROM op.detect_political_entity_members(p_sigla)
)
SELECT CASE
    WHEN p_source_entity_type IN ('coalition', 'gce', 'blank', 'null', 'other')
        THEN p_source_entity_type

    WHEN (SELECT sigla FROM s) IN ('AD', 'PCP-PEV', 'CDU')
        THEN 'coalition'

    WHEN (SELECT sigla FROM s) IN (SELECT member_sigla FROM known_exact_party)
        THEN 'party'

    WHEN (SELECT sigla FROM s) ~ '^(GCE-|MOV|M\.A\.?)'
        THEN 'gce'

    WHEN (SELECT n FROM member_count) >= 2
        THEN 'coalition'

    ELSE 'party'
END;
$$;

CREATE OR REPLACE PROCEDURE op.rebuild_political_entity_members()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE op.political_entity pe
    SET
        entity_type = op.infer_political_entity_type(pe.sigla, pe.entity_type),
        updated_at = now()
    WHERE pe.entity_type IS DISTINCT FROM op.infer_political_entity_type(pe.sigla, pe.entity_type);

    DELETE FROM op.political_entity_member;

    INSERT INTO op.political_entity_member (
        coalition_id,
        member_id
    )
    SELECT DISTINCT
        coalition.political_entity_id AS coalition_id,
        member.political_entity_id AS member_id
    FROM op.political_entity coalition
    JOIN LATERAL op.detect_political_entity_members(coalition.sigla) dm
      ON true
    JOIN op.political_entity member
      ON member.sigla = dm.member_sigla
    WHERE coalition.entity_type = 'coalition'
      AND coalition.political_entity_id <> member.political_entity_id
    ON CONFLICT DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION wh.canonical_political_entity_sigla(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_sigla text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
WITH s AS (
    SELECT op.normalized_sigla(p_sigla) AS sigla
)
SELECT CASE
    /*
      LEGISLATIVAS 2022:
      National AR distribution must display PSD district coalition seats under PPD/PSD.
    */
    WHEN p_election_type = 'LEGISLATIVAS'
     AND p_election_year = 2022
     AND p_office = 'AR'
     AND (SELECT sigla FROM s) IN (
        'PPD/PSD',
        'PSD',
        'PPD/PSD.CDS-PP',
        'PPD/PSD.CDS-PP.PPM',
        'CDS-PP.PPD/PSD',
        'CDS-PP.PPD/PSD.PPM',
        'PPD/PSD-CDS/PP',
        'PSD/CDS',
        'PSD-CDS',
        'PSD.CDS'
     )
        THEN 'PPD/PSD'

    /*
      LEGISLATIVAS 2024/2025:
      AD is the national political identity.
    */
    WHEN p_election_type = 'LEGISLATIVAS'
     AND p_election_year IN (2024, 2025)
     AND p_office = 'AR'
     AND (SELECT sigla FROM s) IN (
        'AD',
        'PPD/PSD.CDS-PP',
        'PPD/PSD.CDS-PP.PPM',
        'PPD/PSD.CDS-PP.PPM.A',
        'CDS-PP.PPD/PSD',
        'CDS-PP.PPD/PSD.PPM',
        'PPD/PSD-CDS/PP',
        'PSD/CDS',
        'PSD-CDS',
        'PSD.CDS'
     )
        THEN 'AD'

    WHEN (SELECT sigla FROM s) IN ('BE', 'B.E')
        THEN 'B.E.'

    WHEN (SELECT sigla FROM s) IN ('RIR', 'R.I.R')
        THEN 'R.I.R.'

    WHEN (SELECT sigla FROM s) IN ('VOLT', 'VOLT.')
        THEN 'VP'

    ELSE (SELECT sigla FROM s)
END;
$$;

DROP TABLE IF EXISTS wh.fact_seat_result CASCADE;
DROP TABLE IF EXISTS wh.fact_vote_result CASCADE;
DROP TABLE IF EXISTS wh.fact_turnout CASCADE;
DROP TABLE IF EXISTS wh.bridge_political_entity_member CASCADE;
DROP TABLE IF EXISTS wh.dim_political_entity CASCADE;
DROP TABLE IF EXISTS wh.dim_territory CASCADE;
DROP TABLE IF EXISTS wh.dim_office CASCADE;
DROP TABLE IF EXISTS wh.dim_election CASCADE;

CREATE TABLE wh.dim_election AS
SELECT
    e.election_id AS election_key,
    e.code AS election_code,
    et.code AS election_type,
    e.name AS election_name,
    e.election_year,
    e.election_date
FROM op.election e
JOIN op.election_type et
  ON et.election_type_id = e.election_type_id;

ALTER TABLE wh.dim_election
ADD PRIMARY KEY (election_key);

CREATE TABLE wh.dim_office AS
SELECT
    office_id AS office_key,
    code AS office_code,
    name AS office_name,
    scope_level
FROM op.office;

ALTER TABLE wh.dim_office
ADD PRIMARY KEY (office_key);

CREATE TABLE wh.dim_territory AS
SELECT
    t.territory_id AS territory_key,
    t.code AS territory_code,
    t.name AS territory_name,
    tl.code AS territory_level,
    p.code AS parent_code,
    p.name AS parent_name,
    t.geom
FROM op.territory t
JOIN op.territory_level tl
  ON tl.territory_level_id = t.level_id
LEFT JOIN op.territory p
  ON p.territory_id = t.parent_id;

ALTER TABLE wh.dim_territory
ADD PRIMARY KEY (territory_key);

CREATE INDEX IF NOT EXISTS wh_dim_territory_code_idx
ON wh.dim_territory(territory_code);

CREATE INDEX IF NOT EXISTS wh_dim_territory_level_idx
ON wh.dim_territory(territory_level);

CREATE INDEX IF NOT EXISTS wh_dim_territory_parent_code_idx
ON wh.dim_territory(parent_code);

CREATE INDEX IF NOT EXISTS wh_dim_territory_geom_gix
ON wh.dim_territory USING gist(geom);

CALL op.rebuild_political_entity_members();

CREATE TABLE wh.dim_political_entity AS
SELECT
    political_entity_id AS political_entity_key,
    sigla,
    name,
    entity_type,
    COALESCE(
        color_hex,
        CASE
            WHEN entity_type = 'coalition' THEN '#6A8F83'
            WHEN entity_type = 'gce'       THEN '#5C7A70'
            WHEN entity_type = 'blank'     THEN '#E7EFEA'
            WHEN entity_type = 'null'      THEN '#172522'
            ELSE                                '#4F6B62'
        END
    ) AS color
FROM op.political_entity;

ALTER TABLE wh.dim_political_entity
ADD PRIMARY KEY (political_entity_key);

CREATE INDEX IF NOT EXISTS wh_dim_political_entity_sigla_idx
ON wh.dim_political_entity(sigla);

CREATE INDEX IF NOT EXISTS wh_dim_political_entity_entity_type_idx
ON wh.dim_political_entity(entity_type);

CREATE TABLE wh.bridge_political_entity_member (
    political_entity_key bigint NOT NULL,
    member_political_entity_key bigint NOT NULL,

    PRIMARY KEY (
        political_entity_key,
        member_political_entity_key
    ),

    FOREIGN KEY (political_entity_key)
        REFERENCES wh.dim_political_entity(political_entity_key)
        ON DELETE CASCADE,

    FOREIGN KEY (member_political_entity_key)
        REFERENCES wh.dim_political_entity(political_entity_key)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS wh_bridge_political_entity_member_member_idx
ON wh.bridge_political_entity_member(member_political_entity_key);

CREATE INDEX IF NOT EXISTS wh_bridge_political_entity_member_entity_idx
ON wh.bridge_political_entity_member(political_entity_key);

INSERT INTO wh.bridge_political_entity_member (
    political_entity_key,
    member_political_entity_key
)
SELECT
    pe.political_entity_key,
    pe.political_entity_key
FROM wh.dim_political_entity pe
ON CONFLICT DO NOTHING;

INSERT INTO wh.bridge_political_entity_member (
    political_entity_key,
    member_political_entity_key
)
SELECT DISTINCT
    m.coalition_id AS political_entity_key,
    m.member_id AS member_political_entity_key
FROM op.political_entity_member m
JOIN wh.dim_political_entity coalition
  ON coalition.political_entity_key = m.coalition_id
JOIN wh.dim_political_entity member
  ON member.political_entity_key = m.member_id
ON CONFLICT DO NOTHING;

INSERT INTO wh.bridge_political_entity_member (
    political_entity_key,
    member_political_entity_key
)
SELECT DISTINCT
    coalition.political_entity_key,
    member.political_entity_key
FROM wh.dim_political_entity coalition
JOIN LATERAL op.detect_political_entity_members(coalition.sigla) dm
  ON true
JOIN wh.dim_political_entity member
  ON member.sigla = dm.member_sigla
WHERE coalition.entity_type = 'coalition'
  AND coalition.political_entity_key <> member.political_entity_key
ON CONFLICT DO NOTHING;

CREATE TABLE wh.fact_turnout AS
SELECT
    tr.election_id AS election_key,
    tr.office_id AS office_key,
    tr.territory_id AS territory_key,
    tr.registered_voters,
    tr.voters,
    tr.blank_votes,
    tr.null_votes,
    rs.candidate_votes,
    rs.total_seats,
    rs.turnout_rate,
    rs.blank_rate,
    rs.null_rate
FROM op.turnout_result tr
LEFT JOIN op.result_summary rs
  ON rs.election_id = tr.election_id
 AND rs.office_id = tr.office_id
 AND rs.territory_id = tr.territory_id;

ALTER TABLE wh.fact_turnout
ADD PRIMARY KEY (election_key, office_key, territory_key);

CREATE INDEX IF NOT EXISTS wh_fact_turnout_territory_idx
ON wh.fact_turnout(territory_key);

CREATE TABLE wh.fact_vote_result AS
SELECT
    vr.election_id AS election_key,
    vr.office_id AS office_key,
    vr.territory_id AS territory_key,
    c.political_entity_id AS political_entity_key,
    vr.votes,
    CASE
        WHEN rs.candidate_votes > 0
        THEN round(vr.votes::numeric / rs.candidate_votes, 6)
    END AS vote_share,
    rank() OVER (
        PARTITION BY vr.election_id, vr.office_id, vr.territory_id
        ORDER BY vr.votes DESC
    ) AS result_rank
FROM op.vote_result vr
JOIN op.candidacy c
  ON c.candidacy_id = vr.candidacy_id
LEFT JOIN op.result_summary rs
  ON rs.election_id = vr.election_id
 AND rs.office_id = vr.office_id
 AND rs.territory_id = vr.territory_id;

ALTER TABLE wh.fact_vote_result
ADD PRIMARY KEY (election_key, office_key, territory_key, political_entity_key);

CREATE INDEX IF NOT EXISTS wh_fact_vote_result_territory_idx
ON wh.fact_vote_result(territory_key);

CREATE INDEX IF NOT EXISTS wh_fact_vote_result_entity_idx
ON wh.fact_vote_result(political_entity_key);

CREATE TABLE wh.fact_seat_result AS
SELECT
    sr.election_id AS election_key,
    sr.office_id AS office_key,
    sr.territory_id AS territory_key,
    c.political_entity_id AS political_entity_key,
    sr.seats,
    sc.seats AS total_seats,
    CASE
        WHEN sc.seats > 0
        THEN round(sr.seats::numeric / sc.seats, 6)
    END AS seat_share,
    sr.method
FROM op.seat_result sr
JOIN op.candidacy c
  ON c.candidacy_id = sr.candidacy_id
LEFT JOIN op.seat_count sc
  ON sc.election_id = sr.election_id
 AND sc.office_id = sr.office_id
 AND sc.territory_id = sr.territory_id;

ALTER TABLE wh.fact_seat_result
ADD PRIMARY KEY (election_key, office_key, territory_key, political_entity_key);

CREATE INDEX IF NOT EXISTS wh_fact_seat_result_territory_idx
ON wh.fact_seat_result(territory_key);

CREATE INDEX IF NOT EXISTS wh_fact_seat_result_entity_idx
ON wh.fact_seat_result(political_entity_key);

CREATE OR REPLACE PROCEDURE wh.refresh_wh()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE
        wh.fact_seat_result,
        wh.fact_vote_result,
        wh.fact_turnout,
        wh.bridge_political_entity_member,
        wh.dim_political_entity,
        wh.dim_territory,
        wh.dim_office,
        wh.dim_election;

    INSERT INTO wh.dim_election
    SELECT
        e.election_id,
        e.code,
        et.code,
        e.name,
        e.election_year,
        e.election_date
    FROM op.election e
    JOIN op.election_type et
      ON et.election_type_id = e.election_type_id;

    INSERT INTO wh.dim_office
    SELECT
        office_id,
        code,
        name,
        scope_level
    FROM op.office;

    INSERT INTO wh.dim_territory
    SELECT
        t.territory_id,
        t.code,
        t.name,
        tl.code,
        p.code,
        p.name,
        t.geom
    FROM op.territory t
    JOIN op.territory_level tl
      ON tl.territory_level_id = t.level_id
    LEFT JOIN op.territory p
      ON p.territory_id = t.parent_id;

    CALL op.rebuild_political_entity_members();

    INSERT INTO wh.dim_political_entity
    SELECT
        political_entity_id,
        sigla,
        name,
        entity_type,
        COALESCE(
            color_hex,
            CASE
                WHEN entity_type = 'coalition' THEN '#6A8F83'
                WHEN entity_type = 'gce'       THEN '#5C7A70'
                WHEN entity_type = 'blank'     THEN '#E7EFEA'
                WHEN entity_type = 'null'      THEN '#172522'
                ELSE                                '#4F6B62'
            END
        ) AS color
    FROM op.political_entity;

    INSERT INTO wh.bridge_political_entity_member (
        political_entity_key,
        member_political_entity_key
    )
    SELECT
        pe.political_entity_key,
        pe.political_entity_key
    FROM wh.dim_political_entity pe
    ON CONFLICT DO NOTHING;

    INSERT INTO wh.bridge_political_entity_member (
        political_entity_key,
        member_political_entity_key
    )
    SELECT DISTINCT
        m.coalition_id,
        m.member_id
    FROM op.political_entity_member m
    JOIN wh.dim_political_entity coalition
      ON coalition.political_entity_key = m.coalition_id
    JOIN wh.dim_political_entity member
      ON member.political_entity_key = m.member_id
    ON CONFLICT DO NOTHING;

    INSERT INTO wh.bridge_political_entity_member (
        political_entity_key,
        member_political_entity_key
    )
    SELECT DISTINCT
        coalition.political_entity_key,
        member.political_entity_key
    FROM wh.dim_political_entity coalition
    JOIN LATERAL op.detect_political_entity_members(coalition.sigla) dm
      ON true
    JOIN wh.dim_political_entity member
      ON member.sigla = dm.member_sigla
    WHERE coalition.entity_type = 'coalition'
      AND coalition.political_entity_key <> member.political_entity_key
    ON CONFLICT DO NOTHING;

    INSERT INTO wh.fact_turnout
    SELECT
        tr.election_id,
        tr.office_id,
        tr.territory_id,
        tr.registered_voters,
        tr.voters,
        tr.blank_votes,
        tr.null_votes,
        rs.candidate_votes,
        rs.total_seats,
        rs.turnout_rate,
        rs.blank_rate,
        rs.null_rate
    FROM op.turnout_result tr
    LEFT JOIN op.result_summary rs
      ON rs.election_id = tr.election_id
     AND rs.office_id = tr.office_id
     AND rs.territory_id = tr.territory_id;

    INSERT INTO wh.fact_vote_result
    SELECT
        vr.election_id,
        vr.office_id,
        vr.territory_id,
        c.political_entity_id,
        vr.votes,
        CASE
            WHEN rs.candidate_votes > 0
            THEN round(vr.votes::numeric / rs.candidate_votes, 6)
        END AS vote_share,
        rank() OVER (
            PARTITION BY vr.election_id, vr.office_id, vr.territory_id
            ORDER BY vr.votes DESC
        ) AS result_rank
    FROM op.vote_result vr
    JOIN op.candidacy c
      ON c.candidacy_id = vr.candidacy_id
    LEFT JOIN op.result_summary rs
      ON rs.election_id = vr.election_id
     AND rs.office_id = vr.office_id
     AND rs.territory_id = vr.territory_id;

    INSERT INTO wh.fact_seat_result
    SELECT
        sr.election_id,
        sr.office_id,
        sr.territory_id,
        c.political_entity_id,
        sr.seats,
        sc.seats,
        CASE
            WHEN sc.seats > 0
            THEN round(sr.seats::numeric / sc.seats, 6)
        END AS seat_share,
        sr.method
    FROM op.seat_result sr
    JOIN op.candidacy c
      ON c.candidacy_id = sr.candidacy_id
    LEFT JOIN op.seat_count sc
      ON sc.election_id = sr.election_id
     AND sc.office_id = sr.office_id
     AND sc.territory_id = sr.territory_id;
END;
$$;

CREATE OR REPLACE FUNCTION wh.political_entity_order(p_sigla text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(
        (SELECT AVG(member_order) FROM op.detect_political_entity_members(p_sigla)),
        CASE
            WHEN op.normalized_sigla(p_sigla) = 'BRANCOS' THEN 1000::numeric
            WHEN op.normalized_sigla(p_sigla) = 'NULOS' THEN 1001::numeric
            ELSE 999::numeric
        END
    );
$$;

CREATE OR REPLACE FUNCTION wh.results_for_territory_parties(
    p_election_type text,
    p_election_year integer,
    p_office text,
    p_territory_code text
)
RETURNS TABLE (
    political_entity_key bigint,
    sigla text,
    name text,
    entity_type text,
    color text,
    votes bigint,
    vote_pct numeric,
    seats integer,
    seat_pct numeric,
    is_winner boolean
)
LANGUAGE sql
STABLE
AS $$
WITH ctx AS (
    SELECT
        e.election_key,
        e.election_type,
        e.election_year,
        o.office_key,
        o.office_code,
        t.territory_key,
        t.territory_code,
        t.territory_level
    FROM wh.dim_election e
    JOIN wh.dim_office o
      ON o.office_code = p_office
    JOIN wh.dim_territory t
      ON t.territory_code = p_territory_code
    WHERE e.election_type = p_election_type
      AND e.election_year = p_election_year
),
target_territories AS (
    SELECT DISTINCT
        rt.territory_key
    FROM ctx
    JOIN wh.dim_territory rt
      ON (
            (
                ctx.territory_code = 'PT'
                AND (
                    (ctx.office_code = 'AR' AND rt.territory_level = 'district')
                    OR (ctx.office_code IN ('PR', 'PE') AND rt.territory_code = 'PT')
                    OR (ctx.office_code IN ('CM', 'AM') AND rt.territory_level = 'municipality')
                    OR (ctx.office_code = 'AF' AND rt.territory_level = 'parish')
                )
            )

            OR

            (
                ctx.territory_level = 'district'
                AND (
                    (ctx.office_code = 'AR' AND rt.territory_code = ctx.territory_code)

                    OR (
                        ctx.office_code IN ('CM', 'AM')
                        AND rt.territory_level = 'municipality'
                        AND rt.parent_code = ctx.territory_code
                    )

                    OR (
                        ctx.office_code = 'AF'
                        AND rt.territory_level = 'parish'
                        AND EXISTS (
                            SELECT 1
                            FROM wh.dim_territory municipality
                            WHERE municipality.territory_code = rt.parent_code
                              AND municipality.parent_code = ctx.territory_code
                        )
                    )
                )
            )

            OR

            (
                ctx.territory_level = 'municipality'
                AND (
                    (ctx.office_code IN ('CM', 'AM') AND rt.territory_code = ctx.territory_code)

                    OR (
                        ctx.office_code = 'AF'
                        AND rt.territory_level = 'parish'
                        AND rt.parent_code = ctx.territory_code
                    )
                )
            )

            OR

            (
                ctx.territory_level = 'parish'
                AND rt.territory_code = ctx.territory_code
            )
      )
),
vote_rows AS (
    SELECT
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        ) AS sigla,
        SUM(f.votes)::bigint AS votes
    FROM ctx
    JOIN wh.fact_vote_result f
      ON f.election_key = ctx.election_key
     AND f.office_key = ctx.office_key
    JOIN target_territories tt
      ON tt.territory_key = f.territory_key
    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = f.political_entity_key
    GROUP BY
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        )
),
seat_rows AS (
    SELECT
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        ) AS sigla,
        SUM(f.seats)::integer AS seats
    FROM ctx
    JOIN wh.fact_seat_result f
      ON f.election_key = ctx.election_key
     AND f.office_key = ctx.office_key
    JOIN target_territories tt
      ON tt.territory_key = f.territory_key
    JOIN wh.dim_political_entity pe
      ON pe.political_entity_key = f.political_entity_key
    GROUP BY
        wh.canonical_political_entity_sigla(
            ctx.election_type,
            ctx.election_year,
            ctx.office_code,
            pe.sigla
        )
),
combined AS (
    SELECT
        COALESCE(v.sigla, s.sigla) AS sigla,
        COALESCE(v.votes, 0)::bigint AS votes,
        COALESCE(s.seats, 0)::integer AS seats
    FROM vote_rows v
    FULL OUTER JOIN seat_rows s
      ON s.sigla = v.sigla
),
totals AS (
    SELECT
        COALESCE(SUM(votes), 0)::numeric AS total_votes,
        COALESCE(SUM(seats), 0)::numeric AS total_seats,
        COALESCE(MAX(votes), 0) AS max_votes
    FROM combined
),
display AS (
    SELECT
        c.sigla,
        c.votes,
        c.seats,
        dpe.political_entity_key,
        COALESCE(dpe.name, c.sigla) AS name,
        COALESCE(dpe.entity_type, op.infer_political_entity_type(c.sigla, NULL)) AS entity_type,
        COALESCE(
            dpe.color,
            CASE
                WHEN op.infer_political_entity_type(c.sigla, NULL) = 'coalition' THEN '#6A8F83'
                WHEN op.infer_political_entity_type(c.sigla, NULL) = 'gce'       THEN '#5C7A70'
                ELSE '#4F6B62'
            END
        ) AS color
    FROM combined c
    LEFT JOIN wh.dim_political_entity dpe
      ON dpe.sigla = c.sigla
)
SELECT
    display.political_entity_key,
    display.sigla,
    display.name,
    display.entity_type,
    display.color,
    display.votes,
    CASE
        WHEN totals.total_votes > 0
        THEN round(display.votes::numeric * 100 / totals.total_votes, 2)
        ELSE 0
    END AS vote_pct,
    display.seats,
    CASE
        WHEN totals.total_seats > 0
        THEN round(display.seats::numeric * 100 / totals.total_seats, 2)
        ELSE 0
    END AS seat_pct,
    display.votes = totals.max_votes AS is_winner
FROM display
CROSS JOIN totals
WHERE display.votes > 0
   OR display.seats > 0
ORDER BY
    wh.political_entity_order(display.sigla) ASC,
    display.seats DESC,
    display.votes DESC,
    display.sigla ASC;
$$;
