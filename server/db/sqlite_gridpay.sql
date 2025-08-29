-- ======================================================
-- Table: users
-- ======================================================
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    password TEXT NOT NULL
);

-- ======================================================
-- Table: meters
-- ======================================================
CREATE TABLE IF NOT EXISTS meters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    meter_number TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'active', -- active / inactive
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ======================================================
-- Table: invoices
-- ======================================================
CREATE TABLE IF NOT EXISTS invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    meter_id INTEGER NOT NULL,
    month TEXT NOT NULL,              
    amount REAL NOT NULL,
    status TEXT DEFAULT 'unpaid',
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meter_id) REFERENCES meters(id)
);

-- ======================================================
-- Table: payments
-- ======================================================
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    payment_method TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    status_payment TEXT NOT NUll,
    paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id)
);

-- ======================================================
-- Example Data
-- ======================================================
INSERT INTO users (name, email, phone, password) VALUES
('Jean Kabila', 'jean.kabila@example.com', '+243812345678', 'hash_pwd1'),
('Amina Mwamba', 'amina.mwamba@example.com', '+243823456789', 'hash_pwd2');

INSERT INTO meters (user_id, meter_number) VALUES
(1, 'MTR-001'),
(1, 'MTR-002'), -- Jean a 2 compteurs
(2, 'MTR-003'); -- Amina a 1 compteur
