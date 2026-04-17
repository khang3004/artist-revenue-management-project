-- =============================================================================
-- db/seeds/V3__seed_contracts.sql
-- Contracts + ISA subtypes, Beneficiaries, Contract Splits
--
-- Post-V9 compatible:
--   • end_date is NOT NULL
--   • distribution_fee_pct in percent (0-100)
--   • copyright_owner is NOT NULL
-- =============================================================================

-- ── Contracts (7) — all 3 ISA types represented ────────────────────────────
INSERT INTO contracts (contract_id, name, start_date, end_date, contract_type, status) VALUES
('10000000-0000-0000-0000-000000000001', 'M-TP Exclusive Recording 2017',        '2017-01-01', '2027-01-01', 'recording',    'active'),
('20000000-0000-0000-0000-000000000002', 'Ngọt Indie Distribution',               '2019-01-01', '2025-12-31', 'distribution', 'active'),
('30000000-0000-0000-0000-000000000003', 'Vũ. UMV Publishing',                    '2021-01-01', '2026-12-31', 'publishing',   'active'),
('40000000-0000-0000-0000-000000000004', 'MONO × M-TP Recording 2023',            '2023-01-01', '2028-12-31', 'recording',    'active'),
('50000000-0000-0000-0000-000000000005', 'Bích Phương × Yeah1 Distribution',      '2019-01-01', '2025-12-31', 'distribution', 'active'),
('60000000-0000-0000-0000-000000000006', 'Đen Vâu × SpaceSpeakers Recording',     '2020-01-01', '2025-12-31', 'recording',    'active'),
('70000000-0000-0000-0000-000000000007', 'Hòa Minzy × UMV Publishing',            '2020-01-01', '2026-06-30', 'publishing',   'active');

-- ── Recording contracts ISA ─────────────────────────────────────────────────
INSERT INTO recording_contracts (contract_id, advance_amount, album_commitment_quantity, exclusivity_years) VALUES
('10000000-0000-0000-0000-000000000001', 500000.0000, 3, 5),
('40000000-0000-0000-0000-000000000004', 200000.0000, 2, 3),
('60000000-0000-0000-0000-000000000006', 300000.0000, 2, 3);

-- ── Distribution contracts ISA (pct in PERCENT 0-100 per V9) ────────────────
INSERT INTO distribution_contracts (contract_id, territory, distribution_fee_pct) VALUES
('20000000-0000-0000-0000-000000000002', 'Global',        15.00),
('50000000-0000-0000-0000-000000000005', 'Asia-Pacific',  12.00);

-- ── Publishing contracts ISA (copyright_owner NOT NULL per V9) ──────────────
INSERT INTO publishing_contracts (contract_id, copyright_owner, sync_rights_included) VALUES
('30000000-0000-0000-0000-000000000003', 'Universal Music Publishing', TRUE),
('70000000-0000-0000-0000-000000000007', 'Universal Music Vietnam',    FALSE);

-- ── Beneficiaries: 7 Artists (A) + 5 Labels (L) ────────────────────────────
INSERT INTO beneficiaries (beneficiary_id, beneficiary_type) VALUES
(1,  'A'),   -- Sơn Tùng M-TP
(2,  'A'),   -- Ngọt
(3,  'A'),   -- Vũ.
(4,  'A'),   -- MONO
(5,  'A'),   -- Bích Phương
(6,  'A'),   -- Đen Vâu
(7,  'A'),   -- Hòa Minzy
(8,  'L'),   -- M-TP Entertainment
(9,  'L'),   -- Indie Music Group
(10, 'L'),   -- Universal Music Vietnam
(11, 'L'),   -- Yeah1 Music
(12, 'L');   -- SpaceSpeakers Label

SELECT setval('beneficiaries_beneficiary_id_seq', 12);

INSERT INTO artist_beneficiaries (beneficiary_id, artist_id) VALUES
(1,  1),     -- Sơn Tùng
(2,  4),     -- Ngọt
(3,  8),     -- Vũ.
(4,  9),     -- MONO
(5,  11),    -- Bích Phương
(6,  3),     -- Đen Vâu
(7,  2);     -- Hòa Minzy

INSERT INTO label_beneficiaries (beneficiary_id, label_id) VALUES
(8,  3),     -- M-TP Ent
(9,  4),     -- Indie Music
(10, 1),     -- UMV
(11, 5),     -- Yeah1
(12, 2);     -- SpaceSpeakers

-- ── Contract Splits (40 rows) ───────────────────────────────────────────────
-- BR-01: sum of share_percentage per (contract, track) ≤ 1.0
INSERT INTO contract_splits (split_id, contract_id, track_id, beneficiary_id, share_percentage, role) VALUES
-- Contract 1: Sơn Tùng Recording → tracks 1-3
( 1, '10000000-0000-0000-0000-000000000001',  1,  1,  0.7000, 'Ca sĩ chính'),
( 2, '10000000-0000-0000-0000-000000000001',  1,  8,  0.3000, 'Label'),
( 3, '10000000-0000-0000-0000-000000000001',  2,  1,  0.7000, 'Ca sĩ chính'),
( 4, '10000000-0000-0000-0000-000000000001',  2,  8,  0.3000, 'Label'),
( 5, '10000000-0000-0000-0000-000000000001',  3,  1,  0.6500, 'Ca sĩ chính'),
( 6, '10000000-0000-0000-0000-000000000001',  3,  8,  0.3500, 'Label'),
-- Contract 2: Ngọt Distribution → tracks 9-11
( 7, '20000000-0000-0000-0000-000000000002',  9,  2,  0.8500, 'Band'),
( 8, '20000000-0000-0000-0000-000000000002',  9,  9,  0.1500, 'Label'),
( 9, '20000000-0000-0000-0000-000000000002', 10,  2,  0.8500, 'Band'),
(10, '20000000-0000-0000-0000-000000000002', 10,  9,  0.1500, 'Label'),
(11, '20000000-0000-0000-0000-000000000002', 11,  2,  0.8500, 'Band'),
(12, '20000000-0000-0000-0000-000000000002', 11,  9,  0.1500, 'Label'),
-- Contract 3: Vũ. Publishing → tracks 12-14
(13, '30000000-0000-0000-0000-000000000003', 12,  3,  0.6000, 'Ca sĩ chính'),
(14, '30000000-0000-0000-0000-000000000003', 12, 10,  0.4000, 'Label'),
(15, '30000000-0000-0000-0000-000000000003', 13,  3,  0.6000, 'Ca sĩ chính'),
(16, '30000000-0000-0000-0000-000000000003', 13, 10,  0.4000, 'Label'),
(17, '30000000-0000-0000-0000-000000000003', 14,  3,  0.6000, 'Ca sĩ chính'),
(18, '30000000-0000-0000-0000-000000000003', 14, 10,  0.4000, 'Label'),
-- Contract 4: MONO Recording → tracks 15-17
(19, '40000000-0000-0000-0000-000000000004', 15,  4,  0.6500, 'Ca sĩ chính'),
(20, '40000000-0000-0000-0000-000000000004', 15,  8,  0.3500, 'Label'),
(21, '40000000-0000-0000-0000-000000000004', 16,  4,  0.6500, 'Ca sĩ chính'),
(22, '40000000-0000-0000-0000-000000000004', 16,  8,  0.3500, 'Label'),
(23, '40000000-0000-0000-0000-000000000004', 17,  4,  0.6500, 'Ca sĩ chính'),
(24, '40000000-0000-0000-0000-000000000004', 17,  8,  0.3500, 'Label'),
-- Contract 5: Bích Phương Distribution → tracks 21-23
(25, '50000000-0000-0000-0000-000000000005', 21,  5,  0.7500, 'Ca sĩ chính'),
(26, '50000000-0000-0000-0000-000000000005', 21, 11,  0.2500, 'Label'),
(27, '50000000-0000-0000-0000-000000000005', 22,  5,  0.7500, 'Ca sĩ chính'),
(28, '50000000-0000-0000-0000-000000000005', 22, 11,  0.2500, 'Label'),
(29, '50000000-0000-0000-0000-000000000005', 23,  5,  0.7500, 'Ca sĩ chính'),
(30, '50000000-0000-0000-0000-000000000005', 23, 11,  0.2500, 'Label'),
-- Contract 6: Đen Vâu Recording → tracks 6-8
(31, '60000000-0000-0000-0000-000000000006',  6,  6,  0.7000, 'Rapper chính'),
(32, '60000000-0000-0000-0000-000000000006',  6, 12,  0.3000, 'Label'),
(33, '60000000-0000-0000-0000-000000000006',  7,  6,  0.7000, 'Rapper chính'),
(34, '60000000-0000-0000-0000-000000000006',  7, 12,  0.3000, 'Label'),
(35, '60000000-0000-0000-0000-000000000006',  8,  6,  0.7000, 'Rapper chính'),
(36, '60000000-0000-0000-0000-000000000006',  8, 12,  0.3000, 'Label'),
-- Contract 7: Hòa Minzy Publishing → tracks 4-5
(37, '70000000-0000-0000-0000-000000000007',  4,  7,  0.7000, 'Ca sĩ chính'),
(38, '70000000-0000-0000-0000-000000000007',  4, 10,  0.3000, 'Label'),
(39, '70000000-0000-0000-0000-000000000007',  5,  7,  0.7000, 'Ca sĩ chính'),
(40, '70000000-0000-0000-0000-000000000007',  5, 10,  0.3000, 'Label');

SELECT setval('contract_splits_split_id_seq', 40);
