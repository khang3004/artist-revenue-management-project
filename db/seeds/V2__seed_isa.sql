-- =============================================================================
-- ISA: Artist hierarchy seed (FIXED VERSION)
-- Compatible with V9 schema state
-- =============================================================================

-- ── Artist roles (OK - no change) ───────────────────────────────────────────
INSERT INTO artist_roles (artist_id, role) VALUES
(1,  'solo'),
(1,  'composer'),
(2,  'solo'),
(3,  'solo'),
(3,  'composer'),
(4,  'band'),
(5,  'solo'),
(6,  'composer'),
(7,  'producer'),
(8,  'solo'),
(8,  'composer'),
(9,  'solo'),
(10, 'solo'),
(11, 'solo'),
(12, 'solo');

-- ── Solo artists ISA sub-type ───────────────────────────────────────────────
INSERT INTO solo_artists (artist_id, vocal_range, talent_agency) VALUES
(1,  'C3-C6',  'M-TP Entertainment'),
(2,  'A3-E5',  NULL),
(3,  'B2-A4',  NULL),
(5,  'C3-G4',  NULL),
(8,  'D3-G5',  NULL),
(9,  'C3-C6',  'M-TP Entertainment'),
(10, 'G3-D6',  NULL),
(11, 'C4-E5',  NULL),
(12, 'A3-F5',  'ICM Entertainment');

-- ── Bands ISA sub-type (FIXED: no member_count column) ─────────────────────
INSERT INTO bands (artist_id, formation_date, is_active) VALUES
(4, '2013-11-01', TRUE);

-- ── Composers ISA sub-type (FIXED: total_works exists) ──────────────────────
INSERT INTO composers (artist_id, pen_name, total_works) VALUES
(1, 'Sơn Tùng',   45),
(3, 'Đen Vâu',    60),
(6, 'Khắc Hưng', 150),
(8, 'Vũ.',        30);

-- ── Producers ISA sub-type ──────────────────────────────────────────────────
INSERT INTO producers (artist_id, studio_name, production_style) VALUES
(7, 'SpaceSpeakers Studio', 'Electronic/Hip-hop');

-- ── Band members (FIXED SAFE FK order assumption) ───────────────────────────
INSERT INTO band_members (band_id, artist_id, join_date, internal_split_pct)
VALUES
(4, 5, '2013-11-01', 0.2500);