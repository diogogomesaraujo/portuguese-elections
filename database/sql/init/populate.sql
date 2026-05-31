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

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'LEGISLATIVAS_2022', 'Eleições Legislativas 2022', DATE '2022-01-30', 2022, 'CNE Quadro de Resultados AR 2022'
FROM op.election_type
WHERE code = 'LEGISLATIVAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'LEGISLATIVAS_2024', 'Eleições Legislativas 2024', DATE '2024-03-10', 2024, 'CNE Quadro de Resultados AR 2024'
FROM op.election_type
WHERE code = 'LEGISLATIVAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'LEGISLATIVAS_2025', 'Eleições Legislativas 2025', DATE '2025-05-18', 2025, 'CNE Quadro de Resultados AR 2025'
FROM op.election_type
WHERE code = 'LEGISLATIVAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();


INSERT INTO op.political_entity(sigla, name, entity_type, color_hex) VALUES
('PS',        'Partido Socialista',                                'party',     '#FF66FF'),
('PPD/PSD',   'Partido Social Democrata',                          'party',     '#F68A21'),
('CH',        'Chega',                                             'party',     '#333399'),
('IL',        'Iniciativa Liberal',                                'party',     '#00AEEE'),
('PCP-PEV',   'CDU - Coligação Democrática Unitária',              'coalition', '#FF0000'),
('B.E.',      'Bloco de Esquerda',                                 'party',     '#DA291C'),
('CDS-PP',    'CDS - Partido Popular',                             'party',     '#0091DC'),
('PAN',       'Pessoas-Animais-Natureza',                          'party',     '#036A84'),
('L',         'LIVRE',                                             'party',     '#C3D304'),
('ADN',       'Alternativa Democrática Nacional',                  'party',     '#274E82'),
('JPP',       'Juntos pelo Povo',                                  'party',     '#0E766D'),
('MPT',       'Partido da Terra',                                  'party',     '#008D45'),
('R.I.R.',    'Reagir Incluir Reciclar',                           'party',     '#20B2AA'),
('PCTP/MRPP', 'Partido Comunista dos Trabalhadores Portugueses',   'party',     '#FF4400'),
('NC',        'Nós, Cidadãos!',                                    'party',     '#FEAB19'),
('PPM',       'Partido Popular Monárquico',                        'party',     '#014A94'),
('A',         'Aliança',                                           'party',     '#024EC9'),
('MAS',       'Movimento Alternativa Socialista',                  'party',     '#DC143C'),
('PDR',       'Partido Democrático Republicano',                   'party',     '#0A2025'),
('PLS',       'Partido Liberal Social',                            'party',     '#FCCB44'),
('PNR',       'Partido Nacional Renovador',                        'party',     '#0D549C'),
('PPV/CDC',   'Portugal Pró Vida / Cidadania e Democracia Cristã', 'party',     '#006682'),
('PTP',       'Partido Trabalhista Português',                     'party',     '#CA0114'),
('PURP',      'Partido Unido dos Reformados e Pensionistas',       'party',     '#259751'),
('E',         'Ergue-te',                                          'party',     '#0D549C'),
('ND',        'Nova Direita',                                      'party',     '#012257'),
('VP',        'Volt Portugal',                                     'party',     '#4B0082')
ON CONFLICT (sigla) DO UPDATE SET
    name = EXCLUDED.name,
    entity_type = EXCLUDED.entity_type,
    color_hex = EXCLUDED.color_hex,
    updated_at = now();
