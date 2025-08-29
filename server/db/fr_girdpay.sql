-- ======================================================
-- Création de la base
-- ======================================================
CREATE DATABASE IF NOT EXISTS electric_pay;
USE electric_pay;

-- ======================================================
-- Table : users
-- ======================================================
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    numero_compteur VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(200) NOT NULL
);

-- ======================================================
-- Table : factures
-- ======================================================
CREATE TABLE factures (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    mois VARCHAR(7) NOT NULL,              -- ex: "2025-08"
    montant DECIMAL(10,2) NOT NULL,
    status ENUM('non_payee','payee') DEFAULT 'non_payee',
    date_emise TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ======================================================
-- Table : paiements
-- ======================================================
CREATE TABLE paiements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    facture_id INT NOT NULL,
    montant DECIMAL(10,2) NOT NULL,
    mode_paiement VARCHAR(50) NOT NULL,    -- ex: Mobile Money, Carte Bancaire
    transaction_id VARCHAR(255) NOT NULL,  -- ID venant du prestataire (CinetPay, etc.)
    date_paiement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (facture_id) REFERENCES factures(id)
);

-- ======================================================
-- Données d'exemple
-- ======================================================

-- Utilisateurs
INSERT INTO users (id, nom, email, numero_compteur, password) VALUES
(1, 'Jean Kabila', 'jean.kabila@example.com', 'CNT-001', 'hash_pwd1'),
(2, 'Amina Mwamba', 'amina.mwamba@example.com', 'CNT-002', 'hash_pwd2'),
(3, 'Patrick Ndala', 'patrick.ndala@example.com', 'CNT-003', 'hash_pwd3');

-- Factures
INSERT INTO factures (id, user_id, mois, montant, status, date_emise) VALUES
(1, 1, '2025-07', 120.50, 'payee', '2025-07-31 20:00:00'),
(2, 1, '2025-08', 135.75, 'non_payee', '2025-08-31 20:00:00'),
(3, 2, '2025-08', 98.00, 'payee', '2025-08-31 20:00:00'),
(4, 3, '2025-08', 200.00, 'non_payee', '2025-08-31 20:00:00');

-- Paiements
INSERT INTO paiements (id, facture_id, montant, mode_paiement, transaction_id, date_paiement) VALUES
(1, 1, 120.50, 'Mobile Money', 'TXN123456', '2025-07-31 21:05:00'),
(2, 3, 98.00, 'Carte Bancaire', 'TXN789012', '2025-08-31 21:45:00');
