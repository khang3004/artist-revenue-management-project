-- =============================================================================
-- db/seeds/01_seed_mock_data.sql
-- Mock Data for Architecture Testing
-- =============================================================================

-- =============================================================================
-- 1. CORE ENTITIES (Migration V1)
-- =============================================================================

INSERT INTO labels (label_id, name, founded_date, contact_email) VALUES
(1, 'Universal Music Vietnam', '2010-01-01', 'contact@umv.vn'),
(2, 'SpaceSpeakers Label', '2020-05-15', 'booking@spacespeakers.vn'),
(3, 'M-TP Entertainment', '2016-11-08', 'info@mtpent.com'),
(4, 'Indie Music Group', '2015-08-20', 'hello@indiegroup.vn');

SELECT setval('labels_label_id_seq', 4);

-- Insert Parents: Artists
INSERT INTO artists (artist_id, stage_name, full_name, label_id) VALUES
(1, 'Son Tung M-TP', 'Nguyen Thanh Tung', 3),      -- Solo + Composer
(2, 'Touliver', 'Nguyen Hoang', 2),                 -- Producer
(3, 'Ngot', 'Ngot Band', 4),                        -- Band
(4, 'Vu.', 'Thai Vu', 1),                           -- Solo + Composer
(5, 'Thang', 'Vu Dinh Trong Thang', NULL),          -- Solo + Band Member
(6, 'Khac Hung', 'Nguyen Khac Hung', 1);            -- Composer

SELECT setval('artists_artist_id_seq', 6);

-- Insert Albums
INSERT INTO albums (album_id, title, release_date, artist_id) VALUES
(1, 'm-tp M-TP', '2017-04-01', 1),
(2, '3', '2019-10-12', 3),
(3, 'Mot Van Nam', '2022-09-09', 4);

SELECT setval('albums_album_id_seq', 3);

-- Insert Tracks
INSERT INTO tracks (track_id, isrc, title, duration_seconds, album_id, play_count) VALUES
(1, 'VNA011700101', 'Lac Troi', 230, 1, 0), -- We start play_count at 0. Update later to check BR-04
(2, 'VNA011700102', 'Noi Nay Co Anh', 260, 1, 0),
(3, 'VNA011900301', 'Lan Cuoi', 200, 2, 0),
(4, 'VNA012200401', 'Buoc Qua Nhau', 255, 3, 0),
(5, 'VNA012200402', 'Xin Loi', 210, 3, 0);

SELECT setval('tracks_track_id_seq', 5);

-- =============================================================================
-- 2. ISA ARTISTS (Migration V2)
-- =============================================================================

-- Assign Roles: Artists can have multiple roles
INSERT INTO artist_roles (artist_id, role) VALUES
(1, 'solo'),      -- Son Tung sings
(1, 'composer'),  -- Son Tung also writes his songs
(2, 'producer'),  -- Touliver produces
(3, 'band'),      -- Ngot is a band
(4, 'solo'),      -- Vu. sings
(4, 'composer'),  -- Vu. writes his songs
(5, 'solo'),      -- Thang has a solo path
(6, 'composer');  -- Khac Hung writes songs

INSERT INTO producers (artist_id, studio_name, production_style) VALUES
(2, 'SpaceSpeakers Studio', 'Electronic/Hip-hop');

INSERT INTO bands (artist_id, formation_date, member_count, is_active) VALUES
(3, '2013-11-01', 4, true);

INSERT INTO composers (artist_id, pen_name, num_compositions) VALUES
(6, 'Khac Hung', 150);

-- Band Members (Thang is in Ngot)
INSERT INTO band_members (band_id, artist_id, join_date, internal_split_pct) VALUES
(3, 5, '2013-11-01', 0.25);

-- =============================================================================
-- 3. CONTRACTS & SPLITS (Migration V3)
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

-- =============================================================================
-- 4. EVENTS & VENUES (Migration V4)
-- =============================================================================

INSERT INTO venues (venue_id, venue_name, capacity) VALUES
(1, 'Quang Truong Dong Kinh Nghia Thuc', 50000),
(2, 'Nha Hat Hoa Binh', 2500);

SELECT setval('venues_venue_id_seq', 2);

INSERT INTO managers (manager_id, manager_name) VALUES
(1, 'Hoang Touliver (Manager Role)'),
(2, 'Nguyen Quang Huy');

SELECT setval('managers_manager_id_seq', 2);

INSERT INTO events (event_id, event_name, event_date, venue_id, manager_id, status) VALUES
(1, 'Sky Tour 2019 - Hanoi', '2019-08-11 19:00:00', 1, 2, 'COMPLETED'),
(2, 'Ngot Live Concert', '2023-10-20 20:00:00', 2, 1, 'COMPLETED');

SELECT setval('events_event_id_seq', 2);

INSERT INTO event_performers (event_id, artist_id, performance_fee, revenue_share_pct) VALUES
(1, 1, 500000.00, NULL),  -- Son Tung gets a flat 500 million fixed fee.
(2, 3, NULL, 0.3000);     -- Ngot takes a 30% revenue share cut of ticket sales.

-- =============================================================================
-- 5. REVENUE, WALLETS, WITHDRAWALS (Migrations V5 & V6)
-- =============================================================================

-- Wallet is auto-created or updated via `trg_revenue_log_credit` (BR-03)
-- Insert Revenue Log for Track 1 (Lac Troi)
-- Gross: $1000. Son Tung should get $700. M-TP Ent gets $300 (but labels don't have wallets in our scheme).
INSERT INTO revenue_logs (log_id, track_id, source, amount, log_date, revenue_type) VALUES
(1, 1, 'Spotify', 1000.0000, '2023-01-15 10:00:00', 'STREAMING');

INSERT INTO streaming_revenue_details (log_id, stream_count, per_stream_rate, platform) VALUES
(1, 200000, 0.005000, 'Spotify');

-- Verify BR-04 constraint by making play_count validly monotonic:
UPDATE tracks SET play_count = 200000 WHERE track_id = 1;

-- Insert Sync Revenue Log for Track 4 (Buoc Qua Nhau)
-- Gross: $5000. Vu. should get $3000 (60%).
INSERT INTO revenue_logs (log_id, track_id, source, amount, log_date, revenue_type) VALUES
(2, 4, 'Netflix', 5000.0000, '2023-05-10 12:00:00', 'SYNC');

INSERT INTO sync_revenue_details (log_id, licensee_name, usage_type) VALUES
(2, 'Netflix OST Usage', 'Film');

-- Insert Live Revenue Log for Event 2 (Ngot) 
-- (track_id IS NULL so BR-03 correctly skips wallet credit, handling it out-of-band for live events)
INSERT INTO revenue_logs (log_id, track_id, source, amount, log_date, revenue_type) VALUES
(3, NULL, 'Ticketbox', 25000.0000, '2023-11-01 09:00:00', 'LIVE');

INSERT INTO live_revenue_details (log_id, event_id, ticket_sold) VALUES
(3, 2, 2500);

SELECT setval('revenue_logs_log_id_seq', 3);

-- Test BR-02: Withdrawals
-- Son Tung (Artist 1) has $700. Try to withdraw $200. 'PENDING' status -> NO wallet balance hit yet.
INSERT INTO withdrawals (withdrawal_id, artist_id, amount, status, method) VALUES
(1, 1, 200.00, 'PENDING', 'bank_transfer');

-- Update status to 'COMPLETED' -> trigger BR-02 reduces Wallet balance to $500.
UPDATE withdrawals SET status = 'COMPLETED', processed_at = NOW() WHERE withdrawal_id = 1;

-- Vu. (Artist 4) has $3000. Withdraw $1500 immediately with 'COMPLETED' -> triggers BR-02 automatically at INSERT.
INSERT INTO withdrawals (withdrawal_id, artist_id, amount, status, method, processed_at) VALUES
(2, 4, 1500.00, 'COMPLETED', 'paypal', NOW());

SELECT setval('withdrawals_withdrawal_id_seq', 2);

-- =============================================================================
-- END OF SQL
-- =============================================================================
