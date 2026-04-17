-- =============================================================================
-- db/seeds/V1__seed_core.sql
-- Labels, Artists (with JSONB metadata), Albums, Tracks
-- Run AFTER all migrations V1–V9 are applied to Neon.
-- =============================================================================

-- ── Labels (6) ──────────────────────────────────────────────────────────────
INSERT INTO labels (label_id, name, founded_date, contact_email) VALUES
(1, 'Universal Music Vietnam', '2010-01-01', 'contact@umv.vn'),
(2, 'SpaceSpeakers Label',     '2020-05-15', 'booking@spacespeakers.vn'),
(3, 'M-TP Entertainment',      '2016-11-08', 'info@mtpent.com'),
(4, 'Indie Music Group',       '2015-08-20', 'hello@indiegroup.vn'),
(5, 'Yeah1 Music',             '2018-03-10', 'music@yeah1.vn'),
(6, 'ICM Entertainment',       '2012-06-01', 'contact@icm.vn');

SELECT setval('labels_label_id_seq', 6);

-- ── Artists (12) — metadata populated for SP8 (GIN @> JSONB search) ─────────
INSERT INTO artists (artist_id, stage_name, full_name, birthday, debut_date, label_id, metadata) VALUES
(1,  'Sơn Tùng M-TP', 'Nguyễn Thanh Tùng',   '1994-07-05', '2012-11-01', 3,
     '{"genre":"V-Pop","country":"VN","social_links":{"instagram":"https://instagram.com/sontungmtp","youtube":"https://youtube.com/@sontungmtp"}}'),
(2,  'Hòa Minzy',     'Nguyễn Thị Hòa',       '1995-08-02', '2014-06-15', 1,
     '{"genre":"Ballad","country":"VN","social_links":{"instagram":"https://instagram.com/hoaminzy"}}'),
(3,  'Đen Vâu',       'Nguyễn Đức Cường',      '1989-05-18', '2013-01-10', 2,
     '{"genre":"Hip-hop","country":"VN","social_links":{"youtube":"https://youtube.com/@denvau"}}'),
(4,  'Ngọt',          'Ngọt Band',              NULL,         '2013-11-01', 4,
     '{"genre":"Indie","country":"VN","social_links":{"instagram":"https://instagram.com/ngotmusic"}}'),
(5,  'Thắng',         'Vũ Đình Trọng Thắng',   '1992-03-22', '2013-11-01', NULL,
     '{"genre":"Indie","country":"VN"}'),
(6,  'Khắc Hưng',     'Nguyễn Khắc Hưng',      '1988-12-10', '2010-01-01', 1,
     '{"genre":"Pop","country":"VN"}'),
(7,  'Touliver',       'Nguyễn Thành Hoàng',    '1989-10-25', '2012-06-01', 2,
     '{"genre":"EDM","country":"VN","social_links":{"instagram":"https://instagram.com/touliver"}}'),
(8,  'Vũ.',           'Thái Vũ',                '1992-08-15', '2017-01-20', 1,
     '{"genre":"Ballad","country":"VN","social_links":{"youtube":"https://youtube.com/@vudot"}}'),
(9,  'MONO',          'Nguyễn Việt Hoàng',      '2000-10-25', '2022-08-01', 3,
     '{"genre":"V-Pop","country":"VN","social_links":{"tiktok":"https://tiktok.com/@monodepzai"}}'),
(10, 'Mỹ Tâm',       'Phan Thị Mỹ Tâm',       '1981-01-16', '2001-06-01', NULL,
     '{"genre":"Pop","country":"VN","social_links":{"instagram":"https://instagram.com/mytamofficial"}}'),
(11, 'Bích Phương',   'Bùi Bích Phương',        '1989-10-21', '2010-05-15', 5,
     '{"genre":"Dance-Pop","country":"VN","social_links":{"youtube":"https://youtube.com/@bichphuong"}}'),
(12, 'Trúc Nhân',     'Nguyễn Trúc Nhân',       '1992-04-22', '2014-01-01', 6,
     '{"genre":"Pop","country":"VN","social_links":{"instagram":"https://instagram.com/trucnhan"}}');

SELECT setval('artists_artist_id_seq', 12);

-- ── Albums (9) ──────────────────────────────────────────────────────────────
INSERT INTO albums (album_id, title, release_date, artist_id) VALUES
(1, 'm-tp M-TP',              '2017-04-01', 1),
(2, 'Hoàng',                  '2020-06-15', 2),
(3, 'dongbac',                '2022-03-20', 3),
(4, '3',                      '2019-10-12', 4),
(5, 'Một Vạn Năm',            '2022-09-09', 8),
(6, '22',                     '2023-11-01', 9),
(7, 'Tâm 9',                  '2018-04-18', 10),
(8, 'Việc Của Em',             '2019-07-25', 11),
(9, 'Mời Anh Vào Team Em',    '2021-12-01', 12);

SELECT setval('albums_album_id_seq', 9);

-- ── Tracks (25) — play_count = all-time cumulative streams ──────────────────
INSERT INTO tracks (track_id, isrc, title, duration_seconds, album_id, play_count) VALUES
-- Album 1: Sơn Tùng M-TP
(1,  'VNA011700101', 'Lạc Trôi',                        230, 1, 850000),
(2,  'VNA011700102', 'Nơi Này Có Anh',                  260, 1, 1200000),
(3,  'VNA011900103', 'Hãy Trao Cho Anh',                280, 1, 2500000),
-- Album 2: Hòa Minzy
(4,  'VNA012000201', 'Không Thể Cùng Nhau Suốt Kiếp',  245, 2, 620000),
(5,  'VNA012000202', 'Rời Bỏ',                          218, 2, 480000),
-- Album 3: Đen Vâu
(6,  'VNA012200301', 'Đi Về Nhà',                       225, 3, 1800000),
(7,  'VNA012200302', 'Mang Tiền Về Cho Mẹ',             248, 3, 3200000),
(8,  'VNA012200303', 'Nấu Ăn Cho Em',                   210, 3, 950000),
-- Album 4: Ngọt
(9,  'VNA011900401', 'Lần Cuối',                         200, 4, 750000),
(10, 'VNA011900402', 'Em Dạo Này',                       195, 4, 520000),
(11, 'VNA011900403', 'Cho Tôi Đi',                       220, 4, 380000),
-- Album 5: Vũ.
(12, 'VNA012200501', 'Bước Qua Nhau',                    255, 5, 680000),
(13, 'VNA012200502', 'Xin Lỗi',                          210, 5, 420000),
(14, 'VNA012200503', 'Lặng',                              190, 5, 310000),
-- Album 6: MONO
(15, 'VNA012300601', 'Waiting For You',                   235, 6, 1500000),
(16, 'VNA012300602', 'Looking For Love',                  200, 6, 980000),
(17, 'VNA012300603', 'Em Là',                             215, 6, 720000),
-- Album 7: Mỹ Tâm
(18, 'VNA011800701', 'Đâu Chỉ Riêng Em',                 240, 7, 900000),
(19, 'VNA011800702', 'Hẫng',                              205, 7, 650000),
(20, 'VNA011800703', 'Người Hãy Quên Em Đi',              230, 7, 1100000),
-- Album 8: Bích Phương
(21, 'VNA011900801', 'Bùa Yêu',                           220, 8, 1800000),
(22, 'VNA011900802', 'Đi Đu Đưa Đi',                      195, 8, 2200000),
(23, 'VNA011900803', 'Một Cú Lừa',                        210, 8, 580000),
-- Album 9: Trúc Nhân
(24, 'VNA012100901', 'Sáng Mắt Chưa',                     235, 9, 1300000),
(25, 'VNA012100902', 'Có Không Giữ Mất Đừng Tìm',         225, 9, 900000);

SELECT setval('tracks_track_id_seq', 25);
