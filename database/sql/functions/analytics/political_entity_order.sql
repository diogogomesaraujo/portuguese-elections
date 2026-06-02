CREATE OR REPLACE FUNCTION wh.political_entity_order(p_sigla text)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
WITH s AS (
    SELECT upper(trim(COALESCE(p_sigla, ''))) AS sigla
),
scores AS (
    /*
      Main left-to-right scale.

      Lower number = more left.
      Higher number = more right.

      For coalitions, the function averages the detected member scores.
      Example:
        PS.L        => average(PS, L)
        PPD/PSD.CDS-PP.PPM => average(PPD/PSD, CDS-PP, PPM)
    */

    SELECT 10::numeric AS score
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])PCP-PEV([^A-Z0-9]|$)'
       OR sigla ~ '(^|[^A-Z0-9])CDU([^A-Z0-9]|$)'

    UNION ALL
    SELECT 20
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])BE([^A-Z0-9]|$)'
       OR sigla ~ '(^|[^A-Z0-9])B\.E\.([^A-Z0-9]|$)'

    UNION ALL
    SELECT 30
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])L([^A-Z0-9]|$)'

    UNION ALL
    SELECT 35
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])PAN([^A-Z0-9]|$)'

    UNION ALL
    SELECT 40
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])PS([^A-Z0-9]|$)'

    UNION ALL
    SELECT 45
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])JPP([^A-Z0-9]|$)'

    UNION ALL
    SELECT 50
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])MPT([^A-Z0-9]|$)'

    UNION ALL
    SELECT 52
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])PDR([^A-Z0-9]|$)'

    UNION ALL
    SELECT 55
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])VOLT([^A-Z0-9]|$)'
       OR sigla ~ '(^|[^A-Z0-9])VP([^A-Z0-9]|$)'

    UNION ALL
    SELECT 60
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])IL([^A-Z0-9]|$)'

    UNION ALL
    SELECT 62
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])RIR([^A-Z0-9]|$)'

    UNION ALL
    SELECT 65
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])ADN([^A-Z0-9]|$)'

    UNION ALL
    SELECT 67
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])NC([^A-Z0-9]|$)'
       OR sigla ~ '(^|[^A-Z0-9])ND([^A-Z0-9]|$)'

    UNION ALL
    SELECT 70
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])PPD/PSD([^A-Z0-9]|$)'
       OR sigla ~ '(^|[^A-Z0-9])PSD([^A-Z0-9]|$)'
       OR sigla ~ '(^|[^A-Z0-9])AD([^A-Z0-9]|$)'

    UNION ALL
    SELECT 72
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])A([^A-Z0-9]|$)'

    UNION ALL
    SELECT 80
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])CDS-PP([^A-Z0-9]|$)'

    UNION ALL
    SELECT 85
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])PPM([^A-Z0-9]|$)'

    UNION ALL
    SELECT 90
    FROM s
    WHERE sigla ~ '(^|[^A-Z0-9])CH([^A-Z0-9]|$)'
)
SELECT COALESCE(AVG(score), 999)
FROM scores;
$$;
