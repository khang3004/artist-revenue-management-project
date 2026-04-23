-- =============================================================================
-- db/seeds/V4__seed_events.sql
-- Venues, Managers, Events, Event Performers
-- 10 events in 2024 (matching SP7 default p_year=2024)
-- =============================================================================

-- ── Venues (6) — venue_address per V7 rename ───────────────────────────────
INSERT INTO venues (venue_id, venue_name, venue_address, capacity) VALUES
(1, 'Quảng trường Đông Kinh Nghĩa Thục', 'Hoàn Kiếm, Hà Nội',              50000),
(2, 'Nhà Hát Hòa Bình',                  '240 Đ. 3 Tháng 2, Q.10, TP.HCM',  2500),
(3, 'Trung tâm Hội nghị Quốc gia',       'Mỹ Đình, Nam Từ Liêm, Hà Nội',    7000),
(4, 'Phố đi bộ Nguyễn Huệ',              'Q.1, TP.HCM',                     30000),
(5, 'Nhà Văn hóa Thanh Niên',            '4 Phạm Ngọc Thạch, Q.1, TP.HCM',  1200),
(6, 'Nhà Hát Lớn Hà Nội',               '1 Tràng Tiền, Hoàn Kiếm, Hà Nội',   600);

SELECT setval('venues_venue_id_seq', 6);

-- ── Managers (4) — manager_phone per V7 rename ─────────────────────────────
INSERT INTO managers (manager_id, manager_name, manager_phone) VALUES
(1, 'Hoàng Touliver',    '0901234567'),
(2, 'Nguyễn Quang Huy', '0912345678'),
(3, 'Trần Thị Mai',      '0923456789'),
(4, 'Lê Minh Đức',       '0934567890');

SELECT setval('managers_manager_id_seq', 4);

-- ── Events (10 in 2024) — notes per V7 addition ────────────────────────────
INSERT INTO events (event_id, event_name, event_date, venue_id, manager_id, status, notes) VALUES
( 1, 'Sky Tour 2024 - Hà Nội',       '2024-01-20 19:00:00', 1, 2, 'COMPLETED', 'Sold out in 2 hours'),
( 2, 'Ngọt Live Concert',             '2024-02-14 20:00:00', 2, 1, 'COMPLETED', 'Valentine special'),
( 3, 'Đen Vâu Hà Nội Show',           '2024-03-15 19:30:00', 3, 3, 'COMPLETED', NULL),
( 4, 'Vũ. Acoustic Night',            '2024-04-10 20:00:00', 5, 1, 'COMPLETED', 'Intimate acoustic set'),
( 5, 'MONO Fan Meeting',              '2024-05-25 18:00:00', 4, 4, 'COMPLETED', NULL),
( 6, 'Bích Phương Dance Show',        '2024-06-20 20:00:00', 2, 3, 'COMPLETED', 'Full production'),
( 7, 'Hòa Minzy Concert',             '2024-08-10 19:00:00', 1, 2, 'COMPLETED', NULL),
( 8, 'Mỹ Tâm Birthday Concert',       '2024-11-16 19:30:00', 6, 4, 'COMPLETED', 'Annual birthday show'),
( 9, 'V-Pop Festival 2024',           '2024-12-21 17:00:00', 1, 2, 'COMPLETED', 'Multi-artist festival'),
(10, 'Trúc Nhân Show',                '2024-09-15 20:00:00', 4, 3, 'COMPLETED', NULL);

SELECT setval('events_event_id_seq', 10);

-- ── Event Performers (12 rows — event 9 has 3 artists) ─────────────────────
INSERT INTO event_performers (event_id, artist_id, performance_fee, revenue_share_pct) VALUES
( 1,  1,  500000.00, NULL),     -- Sơn Tùng: flat fee 500M VND
( 2,  4,  NULL,      0.3000),   -- Ngọt: 30% revenue share
( 3,  3,  300000.00, NULL),     -- Đen Vâu: flat fee
( 4,  8,  NULL,      0.4000),   -- Vũ.: 40% revenue share
( 5,  9,  200000.00, NULL),     -- MONO: flat fee
( 6, 11,  NULL,      0.3500),   -- Bích Phương: 35%
( 7,  2,  250000.00, NULL),     -- Hòa Minzy: flat fee
( 8, 10,  NULL,      0.5000),   -- Mỹ Tâm: 50%
-- V-Pop Festival: multi-performer event
( 9,  1,  400000.00, NULL),     -- Sơn Tùng
( 9,  9,  150000.00, NULL),     -- MONO
( 9, 11,  NULL,      0.2000),   -- Bích Phương
-- Trúc Nhân Show
(10, 12,  NULL,      0.3000);   -- Trúc Nhân: 30%
