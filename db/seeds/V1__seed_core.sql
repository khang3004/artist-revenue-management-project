-- =============================================================================
-- db/seeds/V1__seed_core.sql
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
