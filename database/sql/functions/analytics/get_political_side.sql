CREATE OR REPLACE FUNCTION wh.get_political_side(
    p_political_entity_key bigint
)
    RETURNS text
    LANGUAGE sql
    STABLE
AS $$
WITH members AS (
    SELECT DISTINCT pe.sigla
    FROM wh.bridge_political_entity_member b
             JOIN wh.dim_political_entity pe
                  ON pe.political_entity_key = b.member_political_entity_key
    WHERE b.political_entity_key = p_political_entity_key
),

sigla_self AS (
    SELECT sigla FROM wh.dim_political_entity
    WHERE political_entity_key = p_political_entity_key
),

all_siglas AS (
    SELECT sigla FROM members
    UNION
    SELECT sigla FROM sigla_self
),

counts AS (
    SELECT
        COUNT(*) FILTER (
            WHERE sigla IN (
                'PS', 'BE', 'PCP', 'PCP-PEV', 'PAN', 'L', 'LIVRE',
                'JPP', 'PDR'  -- JPP is regionalist left-leaning; PDR was centre-left
            )
            OR sigla ~ '(^|[^A-Z])(PS|BE|PCP|LIVRE|JPP)([^A-Z]|$)'
        ) AS left_count,

        COUNT(*) FILTER (
            WHERE sigla IN (
                'CH', 'IL', 'PSD', 'PPD/PSD', 'CDS-PP', 'AD',
                'MPT', 'PPM', 'NC',  -- common right-coalition partners
                'PPV', 'PPV/DC', 'PPV/CDC'
            )
            OR sigla ~ '(PPD/PSD|CDS-PP|CH\y)'
        ) AS right_count
    FROM all_siglas
)

SELECT CASE
           WHEN left_count > 0 AND right_count = 0  THEN 'left'
           WHEN right_count > 0 AND left_count = 0  THEN 'right'
           WHEN right_count > 0 AND left_count > 0  THEN 'mixed'
           ELSE 'other'
           END
FROM counts;
$$;
