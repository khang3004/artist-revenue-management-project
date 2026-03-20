-- =============================================================================
-- db/seeds/V4__seed_events.sql
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
