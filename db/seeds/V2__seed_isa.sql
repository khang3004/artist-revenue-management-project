-- =============================================================================
-- db/seeds/V2__seed_isa.sql
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
