-- =============================================================================
-- db/seeds/V5__seed_revenue_wallets.sql
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
