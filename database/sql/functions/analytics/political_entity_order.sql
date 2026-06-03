CREATE OR REPLACE FUNCTION op.normalized_sigla(p_sigla text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
WITH s AS (
    SELECT upper(regexp_replace(COALESCE(p_sigla, ''), '\s+', '', 'g')) AS sigla
)
SELECT CASE
    WHEN (SELECT sigla FROM s) IN ('BE', 'B.E', 'B.E.')
        THEN 'B.E.'

    WHEN (SELECT sigla FROM s) IN ('RIR', 'R.I.R', 'R.I.R.')
        THEN 'R.I.R.'

    WHEN (SELECT sigla FROM s) IN ('VOLT', 'VOLT.')
        THEN 'VP'

    WHEN (SELECT sigla FROM s) = 'PSD'
        THEN 'PPD/PSD'

    ELSE replace(
        (SELECT sigla FROM s),
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

        ('B.E.', 20::numeric, '(^|[.+/\-])(B\.E\.|B\.E|BE)($|[.+/\-])'),

        ('L', 30::numeric, '(^|[.+/\-])L($|[.+/\-])'),
        ('PAN', 35::numeric, '(^|[.+/\-])PAN($|[.+/\-])'),
        ('PS', 40::numeric, '(^|[.+/\-])PS($|[.+/\-])'),
        ('PTP', 42::numeric, '(^|[.+/\-])PTP($|[.+/\-])'),
        ('PURP', 43::numeric, '(^|[.+/\-])PURP($|[.+/\-])'),
        ('JPP', 45::numeric, '(^|[.+/\-])JPP($|[.+/\-])'),
        ('MPT', 50::numeric, '(^|[.+/\-])MPT($|[.+/\-])'),
        ('PDR', 52::numeric, '(^|[.+/\-])PDR($|[.+/\-])'),
        ('VP', 55::numeric, '(^|[.+/\-])(VP|VOLT)($|[.+/\-])'),
        ('PLS', 57::numeric, '(^|[.+/\-])PLS($|[.+/\-])'),
        ('R.I.R.', 62::numeric, '(^|[.+/\-])(R\.I\.R\.|R\.I\.R|RIR)($|[.+/\-])'),
        ('ADN', 65::numeric, '(^|[.+/\-])ADN($|[.+/\-])'),
        ('NC', 67::numeric, '(^|[.+/\-])NC($|[.+/\-])'),
        ('ND', 68::numeric, '(^|[.+/\-])ND($|[.+/\-])'),

        ('PPD/PSD', 70::numeric, '(^|[.+/\-])(PPD/PSD|PSD)($|[.+/\-])'),
        ('A', 72::numeric, '(^|[.+/\-])A($|[.+/\-])'),
        ('CDS-PP', 80::numeric, '(^|[.+/\-])(CDS-PP|CDS/PP|CDS)($|[.+/\-])'),
        ('PPV/CDC', 82::numeric, '(^|[.+/\-])PPV/CDC($|[.+/\-])'),
        ('PPM', 85::numeric, '(^|[.+/\-])PPM($|[.+/\-])'),

        -- IL must be to the right of AD.
        -- AD = average(PPD/PSD 70, CDS-PP 80, PPM 85) = 78.33
        -- IL = 87, therefore AD < IL.
        ('IL', 87::numeric, '(^|[.+/\-])IL($|[.+/\-])'),

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

    SELECT 'CDS-PP'::text AS member_sigla, 80::numeric AS member_order
    FROM s
    WHERE sigla = 'AD'

    UNION ALL

    SELECT 'PPM'::text AS member_sigla, 85::numeric AS member_order
    FROM s
    WHERE sigla = 'AD'
),

exact_party AS (
    SELECT
        k.member_sigla,
        k.member_order
    FROM s
    JOIN op.known_political_party_order() k
      ON k.member_sigla = s.sigla
    WHERE s.sigla <> 'AD'
),

coalition_detected AS (
    SELECT DISTINCT
        k.member_sigla,
        k.member_order
    FROM s
    JOIN op.known_political_party_order() k
      ON s.sigla ~ k.match_pattern
    WHERE s.sigla <> 'AD'
      AND s.sigla <> k.member_sigla
      AND NOT EXISTS (
          SELECT 1
          FROM op.known_political_party_order() kk
          WHERE kk.member_sigla = s.sigla
      )
),

combined AS (
    SELECT member_sigla, member_order
    FROM special_ad

    UNION

    SELECT member_sigla, member_order
    FROM exact_party

    UNION

    SELECT member_sigla, member_order
    FROM coalition_detected
)

SELECT
    member_sigla,
    member_order
FROM combined
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
      National AR distribution displays PSD-led district coalition seats under PPD/PSD.
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

    WHEN (SELECT sigla FROM s) IN ('BE', 'B.E', 'B.E.')
        THEN 'B.E.'

    WHEN (SELECT sigla FROM s) IN ('RIR', 'R.I.R', 'R.I.R.')
        THEN 'R.I.R.'

    WHEN (SELECT sigla FROM s) IN ('VOLT', 'VOLT.')
        THEN 'VP'

    ELSE (SELECT sigla FROM s)
END;
$$;


CREATE OR REPLACE FUNCTION wh.political_entity_order(p_sigla text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
WITH detected AS (
    SELECT member_order
    FROM op.detect_political_entity_members(p_sigla)
)
SELECT COALESCE(
    (SELECT AVG(member_order) FROM detected),
    CASE
        WHEN op.normalized_sigla(p_sigla) = 'BRANCOS' THEN 1000::numeric
        WHEN op.normalized_sigla(p_sigla) = 'NULOS' THEN 1001::numeric
        ELSE 999::numeric
    END
);
$$;
