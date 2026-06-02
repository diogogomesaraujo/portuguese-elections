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
('PS',        'Partido Socialista',                                'party',     '#CF5BAD'),
('PPD/PSD',   'Partido Social Democrata',                          'party',     '#CF895B'),
('CH',        'Chega',                                             'party',     '#5B6BCF'),
('IL',        'Iniciativa Liberal',                                'party',     '#5BC7CF'),
('PCP-PEV',   'CDU - Coligação Democrática Unitária',              'coalition', '#CF5B5B'),
('B.E.',      'Bloco de Esquerda',                                 'party',     '#CF5B6B'),
('CDS-PP',    'CDS - Partido Popular',                             'party',     '#5B8FCF'),
('PAN',       'Pessoas-Animais-Natureza',                          'party',     '#5BA8CF'),
('L',         'LIVRE',                                             'party',     '#B8CF5B'),
('ADN',       'Alternativa Democrática Nacional',                  'party',     '#5B72CF'),
('JPP',       'Juntos pelo Povo',                                  'party',     '#5BCF86'),
('MPT',       'Partido da Terra',                                  'party',     '#5BCF6B'),
('R.I.R.',    'Reagir Incluir Reciclar',                           'party',     '#5BCFB8'),
('PCTP/MRPP', 'Partido Comunista dos Trabalhadores Portugueses',   'party',     '#CF6B5B'),
('NC',        'Nós, Cidadãos!',                                    'party',     '#CFB85B'),
('PPM',       'Partido Popular Monárquico',                        'party',     '#5B5BCF'),
('A',         'Aliança',                                           'party',     '#5B62CF'),
('MAS',       'Movimento Alternativa Socialista',                  'party',     '#CF5B78'),
('PDR',       'Partido Democrático Republicano',                   'party',     '#D4EDE1'),
('PLS',       'Partido Liberal Social',                            'party',     '#CFD05B'),
('PNR',       'Partido Nacional Renovador',                        'party',     '#5B6ACF'),
('PPV/CDC',   'Portugal Pró Vida / Cidadania e Democracia Cristã', 'party',     '#5BAFCF'),
('PTP',       'Partido Trabalhista Português',                     'party',     '#CF5B5B'),
('PURP',      'Partido Unido dos Reformados e Pensionistas',       'party',     '#5BCF75'),
('E',         'Ergue-te',                                          'party',     '#5B6ACF'),
('ND',        'Nova Direita',                                      'party',     '#D4EDE1'),
('VP',        'Volt Portugal',                                     'party',     '#8B5BCF')
ON CONFLICT (sigla) DO UPDATE SET
    name = EXCLUDED.name,
    entity_type = EXCLUDED.entity_type,
    color_hex = EXCLUDED.color_hex,
    updated_at = now();
