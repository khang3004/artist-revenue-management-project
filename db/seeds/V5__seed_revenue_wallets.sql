-- =============================================================================
-- db/seeds/V5__seed_revenue_wallets.sql
-- Revenue Logs (94 rows) + ISA details + Withdrawals (7 rows)
--
-- Wallets auto-created by BR-03 trigger (fn_revenue_log_credit).
-- Wallet debits auto-applied by BR-02 trigger on COMPLETED withdrawals.
--
-- Post-V9 compatible:
--   • usage_type IN ('Phim ảnh','Quảng cáo','Game','Khác')
--   • method    IN ('bank_transfer','momo','zalopay') or NULL
--   • revenue_logs are append-only after V9
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. STREAMING REVENUE (72 logs, log_id 1–72)
--    currency defaults to 'VND'. per_stream_rate = 0.005 (USD scale).
-- ═══════════════════════════════════════════════════════════════════════════════
INSERT INTO revenue_logs (log_id, track_id, source, amount, log_date, revenue_type) VALUES
-- Track 1: Lạc Trôi (Sơn Tùng) — total 4500
( 1,  1, 'Spotify',       1200.0000, '2024-01-15 10:00:00', 'STREAMING'),
( 2,  1, 'Apple Music',   1500.0000, '2024-05-12 10:00:00', 'STREAMING'),
( 3,  1, 'Spotify',       1800.0000, '2024-09-18 10:00:00', 'STREAMING'),
-- Track 2: Nơi Này Có Anh (Sơn Tùng) — total 6000
( 4,  2, 'Spotify',       1800.0000, '2024-02-10 10:00:00', 'STREAMING'),
( 5,  2, 'YouTube Music', 2000.0000, '2024-06-15 10:00:00', 'STREAMING'),
( 6,  2, 'Spotify',       2200.0000, '2024-10-20 10:00:00', 'STREAMING'),
-- Track 3: Hãy Trao Cho Anh (Sơn Tùng) — total 9300
( 7,  3, 'Spotify',       3000.0000, '2024-03-08 10:00:00', 'STREAMING'),
( 8,  3, 'Zing MP3',      2800.0000, '2024-07-14 10:00:00', 'STREAMING'),
( 9,  3, 'Spotify',       3500.0000, '2024-11-22 10:00:00', 'STREAMING'),
-- Track 4: Không Thể Cùng Nhau Suốt Kiếp (Hòa Minzy) — total 3200
(10,  4, 'Spotify',        900.0000, '2024-01-20 10:00:00', 'STREAMING'),
(11,  4, 'Apple Music',   1100.0000, '2024-06-18 10:00:00', 'STREAMING'),
(12,  4, 'Spotify',       1200.0000, '2024-11-10 10:00:00', 'STREAMING'),
-- Track 5: Rời Bỏ (Hòa Minzy) — total 1500
(13,  5, 'Spotify',        800.0000, '2024-03-25 10:00:00', 'STREAMING'),
(14,  5, 'Zing MP3',       700.0000, '2024-08-05 10:00:00', 'STREAMING'),
-- Track 6: Đi Về Nhà (Đen Vâu) — total 7500
(15,  6, 'Spotify',       2500.0000, '2024-02-12 10:00:00', 'STREAMING'),
(16,  6, 'YouTube Music', 2200.0000, '2024-06-22 10:00:00', 'STREAMING'),
(17,  6, 'Spotify',       2800.0000, '2024-10-08 10:00:00', 'STREAMING'),
-- Track 7: Mang Tiền Về Cho Mẹ (Đen Vâu) — total 12300
(18,  7, 'Spotify',       4000.0000, '2024-03-18 10:00:00', 'STREAMING'),
(19,  7, 'Spotify',       3800.0000, '2024-07-25 10:00:00', 'STREAMING'),
(20,  7, 'Zing MP3',      4500.0000, '2024-11-15 10:00:00', 'STREAMING'),
-- Track 8: Nấu Ăn Cho Em (Đen Vâu) — total 4300
(21,  8, 'Spotify',       1500.0000, '2024-04-10 10:00:00', 'STREAMING'),
(22,  8, 'Apple Music',   1200.0000, '2024-08-20 10:00:00', 'STREAMING'),
(23,  8, 'Spotify',       1600.0000, '2024-12-05 10:00:00', 'STREAMING'),
-- Track 9: Lần Cuối (Ngọt) — total 3100
(24,  9, 'Spotify',       1000.0000, '2024-01-22 10:00:00', 'STREAMING'),
(25,  9, 'Apple Music',   1200.0000, '2024-05-18 10:00:00', 'STREAMING'),
(26,  9, 'Spotify',        900.0000, '2024-09-12 10:00:00', 'STREAMING'),
-- Track 10: Em Dạo Này (Ngọt) — total 2400
(27, 10, 'Spotify',        800.0000, '2024-02-28 10:00:00', 'STREAMING'),
(28, 10, 'Zing MP3',       900.0000, '2024-06-14 10:00:00', 'STREAMING'),
(29, 10, 'Spotify',        700.0000, '2024-10-30 10:00:00', 'STREAMING'),
-- Track 11: Cho Tôi Đi (Ngọt) — total 1650
(30, 11, 'Spotify',        600.0000, '2024-04-15 10:00:00', 'STREAMING'),
(31, 11, 'Apple Music',    500.0000, '2024-08-08 10:00:00', 'STREAMING'),
(32, 11, 'Spotify',        550.0000, '2024-12-12 10:00:00', 'STREAMING'),
-- Track 12: Bước Qua Nhau (Vũ.) — total 3400
(33, 12, 'Spotify',       1100.0000, '2024-01-18 10:00:00', 'STREAMING'),
(34, 12, 'YouTube Music', 1300.0000, '2024-05-22 10:00:00', 'STREAMING'),
(35, 12, 'Spotify',       1000.0000, '2024-09-15 10:00:00', 'STREAMING'),
-- Track 13: Xin Lỗi (Vũ.) — total 2150
(36, 13, 'Spotify',        700.0000, '2024-02-14 10:00:00', 'STREAMING'),
(37, 13, 'Apple Music',    800.0000, '2024-07-10 10:00:00', 'STREAMING'),
(38, 13, 'Spotify',        650.0000, '2024-11-05 10:00:00', 'STREAMING'),
-- Track 14: Lặng (Vũ.) — total 1650
(39, 14, 'Spotify',        500.0000, '2024-03-12 10:00:00', 'STREAMING'),
(40, 14, 'Zing MP3',       600.0000, '2024-08-18 10:00:00', 'STREAMING'),
(41, 14, 'Spotify',        550.0000, '2024-12-22 10:00:00', 'STREAMING'),
-- Track 15: Waiting For You (MONO) — total 9500
(42, 15, 'Spotify',       2500.0000, '2024-01-25 10:00:00', 'STREAMING'),
(43, 15, 'Apple Music',   2200.0000, '2024-04-20 10:00:00', 'STREAMING'),
(44, 15, 'Spotify',       2800.0000, '2024-07-18 10:00:00', 'STREAMING'),
(45, 15, 'YouTube Music', 2000.0000, '2024-10-15 10:00:00', 'STREAMING'),
-- Track 16: Looking For Love (MONO) — total 6800
(46, 16, 'Spotify',       1800.0000, '2024-02-20 10:00:00', 'STREAMING'),
(47, 16, 'Zing MP3',      1600.0000, '2024-05-15 10:00:00', 'STREAMING'),
(48, 16, 'Spotify',       1900.0000, '2024-08-12 10:00:00', 'STREAMING'),
(49, 16, 'Apple Music',   1500.0000, '2024-11-08 10:00:00', 'STREAMING'),
-- Track 17: Em Là (MONO) — total 4600
(50, 17, 'Spotify',       1200.0000, '2024-03-22 10:00:00', 'STREAMING'),
(51, 17, 'YouTube Music', 1000.0000, '2024-06-18 10:00:00', 'STREAMING'),
(52, 17, 'Spotify',       1300.0000, '2024-09-14 10:00:00', 'STREAMING'),
(53, 17, 'Spotify',       1100.0000, '2024-12-10 10:00:00', 'STREAMING'),
-- Track 21: Bùa Yêu (Bích Phương) — total 8300
(54, 21, 'Spotify',       2800.0000, '2024-02-18 10:00:00', 'STREAMING'),
(55, 21, 'Apple Music',   2500.0000, '2024-06-10 10:00:00', 'STREAMING'),
(56, 21, 'Spotify',       3000.0000, '2024-10-25 10:00:00', 'STREAMING'),
-- Track 22: Đi Đu Đưa Đi (Bích Phương) — total 10500
(57, 22, 'Spotify',       3500.0000, '2024-03-15 10:00:00', 'STREAMING'),
(58, 22, 'YouTube Music', 3200.0000, '2024-07-22 10:00:00', 'STREAMING'),
(59, 22, 'Spotify',       3800.0000, '2024-11-18 10:00:00', 'STREAMING'),
-- Track 23: Một Cú Lừa (Bích Phương) — total 2700
(60, 23, 'Spotify',        900.0000, '2024-04-08 10:00:00', 'STREAMING'),
(61, 23, 'Zing MP3',       800.0000, '2024-08-25 10:00:00', 'STREAMING'),
(62, 23, 'Spotify',       1000.0000, '2024-12-15 10:00:00', 'STREAMING'),
-- === Non-contracted tracks (no wallet credit from BR-03) ===
-- Track 18: Đâu Chỉ Riêng Em (Mỹ Tâm)
(63, 18, 'Spotify',       1500.0000, '2024-04-12 10:00:00', 'STREAMING'),
(64, 18, 'Apple Music',   1200.0000, '2024-10-08 10:00:00', 'STREAMING'),
-- Track 19: Hẫng (Mỹ Tâm)
(65, 19, 'Spotify',       1000.0000, '2024-05-20 10:00:00', 'STREAMING'),
(66, 19, 'Zing MP3',       800.0000, '2024-11-14 10:00:00', 'STREAMING'),
-- Track 20: Người Hãy Quên Em Đi (Mỹ Tâm)
(67, 20, 'Spotify',       1800.0000, '2024-06-15 10:00:00', 'STREAMING'),
(68, 20, 'YouTube Music', 1500.0000, '2024-12-08 10:00:00', 'STREAMING'),
-- Track 24: Sáng Mắt Chưa (Trúc Nhân)
(69, 24, 'Spotify',       2000.0000, '2024-03-10 10:00:00', 'STREAMING'),
(70, 24, 'Apple Music',   1800.0000, '2024-09-22 10:00:00', 'STREAMING'),
-- Track 25: Có Không Giữ Mất Đừng Tìm (Trúc Nhân)
(71, 25, 'Spotify',       1400.0000, '2024-07-05 10:00:00', 'STREAMING'),
(72, 25, 'Spotify',       1200.0000, '2024-12-18 10:00:00', 'STREAMING');

-- ── Streaming details ───────────────────────────────────────────────────────
INSERT INTO streaming_revenue_details (log_id, stream_count, per_stream_rate, platform) VALUES
( 1,  240000, 0.005000, 'Spotify'),
( 2,  300000, 0.005000, 'Apple Music'),
( 3,  360000, 0.005000, 'Spotify'),
( 4,  360000, 0.005000, 'Spotify'),
( 5,  400000, 0.005000, 'YouTube Music'),
( 6,  440000, 0.005000, 'Spotify'),
( 7,  600000, 0.005000, 'Spotify'),
( 8,  560000, 0.005000, 'Zing MP3'),
( 9,  700000, 0.005000, 'Spotify'),
(10,  180000, 0.005000, 'Spotify'),
(11,  220000, 0.005000, 'Apple Music'),
(12,  240000, 0.005000, 'Spotify'),
(13,  160000, 0.005000, 'Spotify'),
(14,  140000, 0.005000, 'Zing MP3'),
(15,  500000, 0.005000, 'Spotify'),
(16,  440000, 0.005000, 'YouTube Music'),
(17,  560000, 0.005000, 'Spotify'),
(18,  800000, 0.005000, 'Spotify'),
(19,  760000, 0.005000, 'Spotify'),
(20,  900000, 0.005000, 'Zing MP3'),
(21,  300000, 0.005000, 'Spotify'),
(22,  240000, 0.005000, 'Apple Music'),
(23,  320000, 0.005000, 'Spotify'),
(24,  200000, 0.005000, 'Spotify'),
(25,  240000, 0.005000, 'Apple Music'),
(26,  180000, 0.005000, 'Spotify'),
(27,  160000, 0.005000, 'Spotify'),
(28,  180000, 0.005000, 'Zing MP3'),
(29,  140000, 0.005000, 'Spotify'),
(30,  120000, 0.005000, 'Spotify'),
(31,  100000, 0.005000, 'Apple Music'),
(32,  110000, 0.005000, 'Spotify'),
(33,  220000, 0.005000, 'Spotify'),
(34,  260000, 0.005000, 'YouTube Music'),
(35,  200000, 0.005000, 'Spotify'),
(36,  140000, 0.005000, 'Spotify'),
(37,  160000, 0.005000, 'Apple Music'),
(38,  130000, 0.005000, 'Spotify'),
(39,  100000, 0.005000, 'Spotify'),
(40,  120000, 0.005000, 'Zing MP3'),
(41,  110000, 0.005000, 'Spotify'),
(42,  500000, 0.005000, 'Spotify'),
(43,  440000, 0.005000, 'Apple Music'),
(44,  560000, 0.005000, 'Spotify'),
(45,  400000, 0.005000, 'YouTube Music'),
(46,  360000, 0.005000, 'Spotify'),
(47,  320000, 0.005000, 'Zing MP3'),
(48,  380000, 0.005000, 'Spotify'),
(49,  300000, 0.005000, 'Apple Music'),
(50,  240000, 0.005000, 'Spotify'),
(51,  200000, 0.005000, 'YouTube Music'),
(52,  260000, 0.005000, 'Spotify'),
(53,  220000, 0.005000, 'Spotify'),
(54,  560000, 0.005000, 'Spotify'),
(55,  500000, 0.005000, 'Apple Music'),
(56,  600000, 0.005000, 'Spotify'),
(57,  700000, 0.005000, 'Spotify'),
(58,  640000, 0.005000, 'YouTube Music'),
(59,  760000, 0.005000, 'Spotify'),
(60,  180000, 0.005000, 'Spotify'),
(61,  160000, 0.005000, 'Zing MP3'),
(62,  200000, 0.005000, 'Spotify'),
(63,  300000, 0.005000, 'Spotify'),
(64,  240000, 0.005000, 'Apple Music'),
(65,  200000, 0.005000, 'Spotify'),
(66,  160000, 0.005000, 'Zing MP3'),
(67,  360000, 0.005000, 'Spotify'),
(68,  300000, 0.005000, 'YouTube Music'),
(69,  400000, 0.005000, 'Spotify'),
(70,  360000, 0.005000, 'Apple Music'),
(71,  280000, 0.005000, 'Spotify'),
(72,  240000, 0.005000, 'Spotify');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. SYNC REVENUE (12 logs, log_id 73–84)
--    usage_type per V9 CHECK: 'Phim ảnh' | 'Quảng cáo' | 'Game' | 'Khác'
-- ═══════════════════════════════════════════════════════════════════════════════
INSERT INTO revenue_logs (log_id, track_id, source, amount, log_date, revenue_type) VALUES
(73,  1, 'Netflix Vietnam',     15000.0000, '2024-05-20 12:00:00', 'SYNC'),
(74,  2, 'Samsung Vietnam',      8000.0000, '2024-07-15 12:00:00', 'SYNC'),
(75,  3, 'VinFast',             20000.0000, '2024-09-10 12:00:00', 'SYNC'),
(76,  6, 'Netflix Vietnam',     12000.0000, '2024-03-05 12:00:00', 'SYNC'),
(77,  7, 'Pepsi',               18000.0000, '2024-06-25 12:00:00', 'SYNC'),
(78,  9, 'Garena',              10000.0000, '2024-04-18 12:00:00', 'SYNC'),
(79, 12, 'VTV',                  8000.0000, '2024-08-22 12:00:00', 'SYNC'),
(80, 15, 'TikTok Vietnam',      12000.0000, '2024-02-28 12:00:00', 'SYNC'),
(81, 18, 'K+ Drama',            10000.0000, '2024-10-05 12:00:00', 'SYNC'),
(82, 21, 'Vinamilk',            15000.0000, '2024-06-12 12:00:00', 'SYNC'),
(83, 22, 'VNG',                 10000.0000, '2024-11-20 12:00:00', 'SYNC'),
(84, 24, 'Truyền hình An Viên',  5000.0000, '2024-12-01 12:00:00', 'SYNC');

INSERT INTO sync_revenue_details (log_id, licensee_name, usage_type) VALUES
(73, 'Netflix Vietnam OST',       'Phim ảnh'),
(74, 'Samsung Galaxy Ad',         'Khác'),
(75, 'VinFast TVC 2024',          'Quảng cáo'),
(76, 'Netflix Vietnam Drama',     'Phim ảnh'),
(77, 'Pepsi Summer Campaign',     'Quảng cáo'),
(78, 'Garena Free Fire Theme',    'Game'),
(79, 'VTV Phim Cuối Tuần',        'Phim ảnh'),
(80, 'TikTok Vietnam Campaign',   'Quảng cáo'),
(81, 'K+ Korean Drama OST',       'Phim ảnh'),
(82, 'Vinamilk TVC',              'Quảng cáo'),
(83, 'VNG Game Soundtrack',        'Game'),
(84, 'An Viên Media',              'Khác');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. LIVE REVENUE (10 logs, log_id 85–94)
--    track_id = NULL (live revenue not track-specific → BR-03 skips wallet)
--    event_id NOT NULL per V7
-- ═══════════════════════════════════════════════════════════════════════════════
INSERT INTO revenue_logs (log_id, track_id, source, amount, log_date, revenue_type) VALUES
(85, NULL, 'Ticketbox', 150000.0000, '2024-01-20 21:00:00', 'LIVE'),
(86, NULL, 'Ticketbox',  25000.0000, '2024-02-14 22:00:00', 'LIVE'),
(87, NULL, 'Ticketbox',  80000.0000, '2024-03-15 21:30:00', 'LIVE'),
(88, NULL, 'Ticketbox',  12000.0000, '2024-04-10 22:00:00', 'LIVE'),
(89, NULL, 'Ticketbox',  45000.0000, '2024-05-25 20:00:00', 'LIVE'),
(90, NULL, 'Ticketbox',  30000.0000, '2024-06-20 22:00:00', 'LIVE'),
(91, NULL, 'Ticketbox',  60000.0000, '2024-08-10 21:00:00', 'LIVE'),
(92, NULL, 'Ticketbox',  15000.0000, '2024-11-16 21:30:00', 'LIVE'),
(93, NULL, 'Ticketbox', 200000.0000, '2024-12-21 22:00:00', 'LIVE'),
(94, NULL, 'Ticketbox',  35000.0000, '2024-09-15 22:00:00', 'LIVE');

INSERT INTO live_revenue_details (log_id, event_id, ticket_sold) VALUES
(85,  1, 45000),
(86,  2,  2000),
(87,  3,  6500),
(88,  4,   800),
(89,  5, 25000),
(90,  6,  2200),
(91,  7, 35000),
(92,  8,   600),
(93,  9, 48000),
(94, 10, 18000);

SELECT setval('revenue_logs_log_id_seq', 94);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. WITHDRAWALS (7 rows)
--    Covers all 4 statuses: COMPLETED, PENDING, APPROVED, REJECTED
--    method per V9 CHECK: 'bank_transfer' | 'momo' | 'zalopay' | NULL
--
--    Wallet balances (computed by BR-03 trigger):
--      Sơn Tùng:     42495.00   Hòa Minzy:  3290.00
--      Đen Vâu:      37870.00   Ngọt:      14577.50
--      Vũ.:           9120.00   MONO:      21385.00
--      Bích Phương:  34875.00
-- ═══════════════════════════════════════════════════════════════════════════════
INSERT INTO withdrawals (withdrawal_id, artist_id, amount, status, method, requested_at, processed_at) VALUES
(1,  1, 20000.00, 'COMPLETED',  'bank_transfer', '2024-10-01 09:00:00', '2024-10-03 14:00:00'),
(2,  3, 15000.00, 'COMPLETED',  'momo',          '2024-09-15 10:00:00', '2024-09-17 11:00:00'),
(3,  9,  8000.00, 'PENDING',    'zalopay',       '2024-12-20 08:00:00', NULL),
(4, 11, 10000.00, 'PENDING',    'bank_transfer', '2024-12-22 09:00:00', NULL),
(5,  8,  3000.00, 'COMPLETED',  'momo',          '2024-11-05 10:00:00', '2024-11-07 15:00:00'),
(6,  4, 20000.00, 'REJECTED',   'bank_transfer', '2024-08-10 11:00:00', '2024-08-12 09:00:00'),
(7,  2,  1000.00, 'APPROVED',   'zalopay',       '2024-12-15 14:00:00', '2024-12-16 10:00:00');

SELECT setval('withdrawals_withdrawal_id_seq', 7);

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPECTED WALLET BALANCES (after BR-02 debits for COMPLETED):
--   Sơn Tùng:     42495.00 − 20000 = 22495.00
--   Hòa Minzy:     3290.00
--   Đen Vâu:      37870.00 − 15000 = 22870.00
--   Ngọt:         14577.50           (REJECTED — no debit)
--   Vũ.:           9120.00 −  3000 =  6120.00
--   MONO:         21385.00           (PENDING — no debit)
--   Bích Phương:  34875.00           (PENDING — no debit)
-- ═══════════════════════════════════════════════════════════════════════════════
