INSERT INTO op.territory_level(code, name, depth) VALUES
('country','Country',0),
('district','District / Island',1),
('municipality','Municipality',2),
('parish','Parish',3)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, depth = EXCLUDED.depth;

INSERT INTO op.election_type(code, name) VALUES
('AUTARQUICAS','Eleições Autárquicas'),
('LEGISLATIVAS','Eleições Legislativas'),
('PRESIDENCIAIS','Eleições Presidenciais'),
('EUROPEIAS','Eleições Europeias')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO op.office(code, name, scope_level) VALUES
('CM','Câmara Municipal','municipality'),
('AM','Assembleia Municipal','municipality'),
('AF','Assembleia de Freguesia','parish'),
('AR','Assembleia da República','district'),
('PR','Presidência da República','country'),
('PE','Parlamento Europeu','country')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, scope_level = EXCLUDED.scope_level;

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'AUTARQUICAS_2017', 'Eleições Autárquicas 2017', DATE '2017-10-01', 2017, 'CNE Mapa Oficial'
FROM op.election_type
WHERE code = 'AUTARQUICAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'AUTARQUICAS_2021', 'Eleições Autárquicas 2021', DATE '2021-09-26', 2021, 'CNE Mapa Oficial'
FROM op.election_type
WHERE code = 'AUTARQUICAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'AUTARQUICAS_2025', 'Eleições Autárquicas 2025', DATE '2025-10-12', 2025, 'CNE Mapa Oficial'
FROM op.election_type
WHERE code = 'AUTARQUICAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();
