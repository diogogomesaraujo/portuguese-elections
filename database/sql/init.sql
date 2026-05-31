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
('PS',        'Partido Socialista',                              'party',     '#FF66A3'),
('PPD/PSD',   'Partido Social Democrata',                        'party',     '#F28C00'),
('CH',        'Chega',                                            'party',     '#202A44'),
('IL',        'Iniciativa Liberal',                              'party',     '#00AEEF'),
('PCP-PEV',   'CDU - Coligação Democrática Unitária',             'coalition', '#D71920'),
('B.E.',      'Bloco de Esquerda',                               'party',     '#8B0000'),
('CDS-PP',    'CDS - Partido Popular',                           'party',     '#0093DD'),
('PAN',       'Pessoas-Animais-Natureza',                        'party',     '#007A3D'),
('L',         'LIVRE',                                            'party',     '#C51B8A'),
('ADN',       'Alternativa Democrática Nacional',                'party',     '#1E88E5'),
('JPP',       'Juntos pelo Povo',                                 'party',     '#00A651'),
('MPT',       'Partido da Terra',                                 'party',     '#6AB04C'),
('R.I.R.',    'Reagir Incluir Reciclar',                          'party',     '#F4C430'),
('PCTP/MRPP', 'Partido Comunista dos Trabalhadores Portugueses',   'party',     '#B30000'),
('NC',        'Nós, Cidadãos!',                                  'party',     '#6C63FF'),
('PPM',       'Partido Popular Monárquico',                      'party',     '#0057B8'),
('A',         'Aliança',                                          'party',     '#00A6A6'),
('MAS',       'Movimento Alternativa Socialista',                 'party',     '#7B1FA2'),
('PDR',       'Partido Democrático Republicano',                  'party',     '#607D8B'),
('PLS',       'Partido Liberal Social',                           'party',     '#9C27B0'),
('PNR',       'Partido Nacional Renovador',                       'party',     '#4E342E'),
('PPV/CDC',   'Portugal Pró Vida / Cidadania e Democracia Cristã', 'party',     '#795548'),
('PTP',       'Partido Trabalhista Português',                    'party',     '#FF9800'),
('PURP',      'Partido Unido dos Reformados e Pensionistas',       'party',     '#9E9E9E'),
('E',         'Ergue-te',                                         'party',     '#111111'),
('ND',        'Nova Direita',                                     'party',     '#263238'),
('VP',        'Volt Portugal',                                    'party',     '#502379')
ON CONFLICT (sigla) DO UPDATE SET
    name = EXCLUDED.name,
    entity_type = EXCLUDED.entity_type,
    color_hex = EXCLUDED.color_hex,
    updated_at = now();
