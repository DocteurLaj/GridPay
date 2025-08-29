-- ======================================================
-- Create Database
-- ======================================================
CREATE DATABASE IF NOT EXISTS gridpay;
USE gridpay;

-- ======================================================
-- Table: users
-- ======================================================
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    meter_number VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(200) NOT NULL
);

-- ======================================================
-- Table: invoices
-- ======================================================
CREATE TABLE invoices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    month VARCHAR(7) NOT NULL,              -- e.g. "2025-08"
    amount DECIMAL(10,2) NOT NULL,
    status ENUM('unpaid','paid') DEFAULT 'unpaid',
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ======================================================
-- Table: payments
-- ======================================================
CREATE TABLE payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,    -- e.g. Mobile Money, Credit Card
    transaction_id VARCHAR(255) NOT NULL,   -- ID from payment provider
    paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
);

-- ======================================================
-- Example Data
-- ======================================================

-- Users
INSERT INTO users (name, email, phone, meter_number, password) VALUES
('Jean Kabila', 'jean.kabila@example.com', '+243810000001', 'MTR-001', 'hash_pwd1'),
('Amina Mwamba', 'amina.mwamba@example.com', '+243810000002', 'MTR-002', 'hash_pwd2'),
('Patrick Ndala', 'patrick.ndala@example.com', '+243810000003', 'MTR-003', 'hash_pwd3');

-- Invoices
INSERT INTO invoices (user_id, month, amount, status, issued_at) VALUES
(1, '2025-07', 120.50, 'paid', '2025-07-31 20:00:00'),
(1, '2025-08', 135.75, 'unpaid', '2025-08-31 20:00:00'),
(2, '2025-08', 98.00, 'paid', '2025-08-31 20:00:00'),
(3, '2025-08', 200.00, 'unpaid', '2025-08-31 20:00:00');

-- Payments
INSERT INTO payments (invoice_id, amount, payment_method, transaction_id, paid_at) VALUES
(1, 120.50, 'Mobile Money', 'TXN123456', '2025-07-31 21:05:00'),
(3, 98.00, 'Credit Card', 'TXN789012', '2025-08-31 21:45:00');
