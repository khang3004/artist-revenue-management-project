-- =============================================================================
-- db/seeds/V3__seed_contracts.sql
-- =============================================================================

-- Contract 1: Son Tung M-TP Recording (UUID: 10000000-0000-0000-0000-000000000001)
-- Contract 2: Ngot Distribution (UUID: 20000000-0000-0000-0000-000000000002)
-- Contract 3: Vu. Publishing (UUID: 30000000-0000-0000-0000-000000000003)

INSERT INTO contracts (contract_id, name, contract_type, start_date, status) VALUES
('10000000-0000-0000-0000-000000000001', 'M-TP Exclusive Recording 2017', 'recording', '2017-01-01', 'active'),
('20000000-0000-0000-0000-000000000002', 'Ngot Indie Distribution', 'distribution', '2019-01-01', 'active'),
('30000000-0000-0000-0000-000000000003', 'Vu. UMV Publishing', 'publishing', '2021-01-01', 'active');

INSERT INTO recording_contracts (contract_id, advance_amount, album_commitment_quantity, exclusivity_years) VALUES
('10000000-0000-0000-0000-000000000001', 500000.0000, 3, 5);

INSERT INTO distribution_contracts (contract_id, territory, distribution_fee_pct) VALUES
('20000000-0000-0000-0000-000000000002', 'Global', 0.1500);

INSERT INTO publishing_contracts (contract_id, copyright_owner, sync_rights_included) VALUES
('30000000-0000-0000-0000-000000000003', 'Universal Music Publishing', true);

-- Beneficiaries
-- A=artist (1=Son Tung, 3=Ngot, 4=Vu.)
-- L=label (1=UMV, 3=M-TP Ent)
INSERT INTO beneficiaries (beneficiary_id, beneficiary_type) VALUES
(1, 'A'), -- Son Tung M-TP
(2, 'A'), -- Ngot
(3, 'A'), -- Vu.
(4, 'L'), -- UMV
(5, 'L'); -- M-TP Ent

SELECT setval('beneficiaries_beneficiary_id_seq', 5);

INSERT INTO artist_beneficiaries (beneficiary_id, artist_id) VALUES
(1, 1), (2, 3), (3, 4);

INSERT INTO label_beneficiaries (beneficiary_id, label_id) VALUES
(4, 1), (5, 3);

-- Contract Splits
-- BR-01: Sum of share_percentage per (contract, track) must not exceed 1.0
-- Contract 1 (M-TP) splits for Track 1 & 2: 70% Son Tung, 30% M-TP Ent
INSERT INTO contract_splits (split_id, contract_id, track_id, beneficiary_id, share_percentage, role) VALUES
(1, '10000000-0000-0000-0000-000000000001', 1, 1, 0.7000, 'Main Artist'),
(2, '10000000-0000-0000-0000-000000000001', 1, 5, 0.3000, 'Label'),
(3, '10000000-0000-0000-0000-000000000001', 2, 1, 0.7000, 'Main Artist'),
(4, '10000000-0000-0000-0000-000000000001', 2, 5, 0.3000, 'Label');

-- Contract 2 (Ngot) splits for Track 3: 100% Ngot
INSERT INTO contract_splits (split_id, contract_id, track_id, beneficiary_id, share_percentage, role) VALUES
(5, '20000000-0000-0000-0000-000000000002', 3, 2, 1.0000, 'Band');

-- Contract 3 (Vu.) splits for Track 4: 60% Vu., 40% UMV
INSERT INTO contract_splits (split_id, contract_id, track_id, beneficiary_id, share_percentage, role) VALUES
(6, '30000000-0000-0000-0000-000000000003', 4, 3, 0.6000, 'Main Artist'),
(7, '30000000-0000-0000-0000-000000000003', 4, 4, 0.4000, 'Label');

SELECT setval('contract_splits_split_id_seq', 7);

-- Note on BR-01: An attempted insertion of an excess split fraction would correctly fail.
