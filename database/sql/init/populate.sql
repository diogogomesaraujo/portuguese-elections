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
SELECT election_type_id, 'LEGISLATIVAS_2015', 'Eleições Legislativas 2015', DATE '2015-10-04', 2015, 'CNE Quadro de Resultados AR 2015'
FROM op.election_type
WHERE code = 'LEGISLATIVAS'
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    election_date = EXCLUDED.election_date,
    election_year = EXCLUDED.election_year,
    source_name = EXCLUDED.source_name,
    updated_at = now();

INSERT INTO op.election(election_type_id, code, name, election_date, election_year, source_name)
SELECT election_type_id, 'LEGISLATIVAS_2019', 'Eleições Legislativas 2019', DATE '2019-10-06', 2019, 'CNE Quadro de Resultados AR 2019'
FROM op.election_type
WHERE code = 'LEGISLATIVAS'
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
('AD',      'Aliança Democrática',   'coalition', '#E8924A'),('PS',        'Partido Socialista',                               'party',     '#E8629A'),
('PPD/PSD',   'Partido Social Democrata',                         'party',     '#E8924A'),
('CH',        'Chega',                                            'party',     '#5C72E8'),
('IL',        'Iniciativa Liberal',                               'party',     '#3CC9D6'),
('PCP-PEV',   'CDU - Coligação Democrática Unitária',            'coalition', '#E85555'),
('B.E.',      'Bloco de Esquerda',                               'party',     '#E84A64'),
('CDS-PP',    'CDS - Partido Popular',                           'party',     '#4A96E8'),
('PAN',       'Pessoas-Animais-Natureza',                         'party',     '#3ABDE8'),
('L',         'LIVRE',                                            'party',     '#A8D63C'),
('ADN',       'Alternativa Democrática Nacional',                 'party',     '#4A7AE8'),
('JPP',       'Juntos pelo Povo',                                 'party',     '#3AE888'),
('MPT',       'Partido da Terra',                                 'party',     '#3AE855'),
('R.I.R.',    'Reagir Incluir Reciclar',                          'party',     '#3AEAC2'),
('PCTP/MRPP', 'Partido Comunista dos Trabalhadores Portugueses',  'party',     '#E8604A'),
('NC',        'Nós, Cidadãos!',                                   'party',     '#E8C240'),
('PPM',       'Partido Popular Monárquico',                       'party',     '#7070E8'),
('A',         'Aliança',                                          'party',     '#5A6AE8'),
('MAS',       'Movimento Alternativa Socialista',                 'party',     '#E84A80'),
('PDR',       'Partido Democrático Republicano',                  'party',     '#64B89A'),
('PLS',       'Partido Liberal Social',                           'party',     '#D6DA3A'),
('PNR',       'Partido Nacional Renovador',                       'party',     '#4A5AE8'),
('PPV/CDC',   'Portugal Pró Vida / Cidadania e Democracia Cristã','party',     '#3AB8E8'),
('PTP',       'Partido Trabalhista Português',                    'party',     '#E84040'),
('PURP',      'Partido Unido dos Reformados e Pensionistas',      'party',     '#3AE870'),
('E',         'Ergue-te',                                         'party',     '#4A5AE8'),
('ND',        'Nova Direita',                                     'party',     '#78A898'),
('VP',        'Volt Portugal',                                    'party',     '#9A60E8')
ON CONFLICT (sigla) DO UPDATE SET
    name = EXCLUDED.name,
    entity_type = EXCLUDED.entity_type,
    color_hex = EXCLUDED.color_hex,
    updated_at = now();
