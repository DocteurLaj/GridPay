# setup_db.py
import sqlite3
import datetime

DB = "gridpay.db"

def create_tables():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    # Table des utilisateurs avec téléphone
    cur.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        meter_number TEXT UNIQUE NOT NULL
    )
    """)

    # Table des compteurs (facultatif, pour séparer la relation)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meter_number TEXT UNIQUE NOT NULL,
        user_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
    """)

    # Table des factures
    cur.execute("""
    CREATE TABLE IF NOT EXISTS facture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        total_kwh REAL DEFAULT 0,
        status TEXT DEFAULT 'unpaid',  -- unpaid ou paid
        date_limit DATE,
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
    """)

    conn.commit()
    conn.close()
    print("[INFO] Tables created successfully.")

def add_test_users():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    users = [
        ("Alice", "alice@example.com", "+243810000001", "CNT-001"),
        ("Bob", "bob@example.com", "+243810000002", "CNT-002"),
        ("Charlie", "charlie@example.com", "+243810000003", "CNT-003")
    ]

    for name, email, phone, meter in users:
        try:
            cur.execute("INSERT INTO users (name, email, phone, meter_number) VALUES (?, ?, ?, ?)", 
                        (name, email, phone, meter))
        except sqlite3.IntegrityError:
            print(f"[WARN] User {name} already exists.")
    
    conn.commit()
    conn.close()
    print("[INFO] Test users added successfully.")

if __name__ == "__main__":
    create_tables()
    add_test_users()
