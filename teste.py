import mysql.connector
from datetime import datetime
import os

# ⚙️ Configuration MySQL
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": os.getenv("DB_PASSWORD", "ton_mot_de_passe"),
    "database": "gridpay"
}

# Prix du kWh
PRICE_PER_KWH = 0.5  # 0,5 USD/kWh

# Connexion à MySQL
conn = mysql.connector.connect(**DB_CONFIG)
cursor = conn.cursor()

# Création des tables
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    phone VARCHAR(20)
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS meters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    meter_number VARCHAR(50) UNIQUE,
    threshold_kwh FLOAT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS invoices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount FLOAT,
    kwh FLOAT,
    threshold_date DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT,
    amount FLOAT,
    payment_date DATETIME,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
)
""")

conn.commit()

# ---------------------- Fonctions ----------------------

def add_user():
    name = input("Nom de l'utilisateur : ")
    phone = input("Téléphone : ")
    meter_number = input("Numéro du compteur : ")
    cursor.execute("INSERT INTO users (name, phone) VALUES (%s, %s)", (name, phone))
    user_id = cursor.lastrowid
    cursor.execute("INSERT INTO meters (user_id, meter_number) VALUES (%s, %s)", (user_id, meter_number))
    conn.commit()
    print(f"[✅] Utilisateur '{name}' ajouté avec le compteur '{meter_number}' (ID: {user_id})")

def pay_amount():
    user_id = int(input("ID de l'utilisateur : "))
    
    # Vérifier utilisateur
    cursor.execute("SELECT id FROM users WHERE id=%s", (user_id,))
    if not cursor.fetchone():
        print("[❌] Utilisateur non trouvé.")
        return

    amount = float(input("Montant à payer ($) : "))
    kwh = amount / PRICE_PER_KWH
    threshold_date = datetime.now()

    # Créer facture
    cursor.execute(
        "INSERT INTO invoices (user_id, amount, kwh, threshold_date) VALUES (%s, %s, %s, %s)",
        (user_id, amount, kwh, threshold_date)
    )
    invoice_id = cursor.lastrowid

    # Enregistrer paiement
    cursor.execute(
        "INSERT INTO payments (invoice_id, amount, payment_date) VALUES (%s, %s, %s)",
        (invoice_id, amount, datetime.now())
    )

    # Mettre à jour seuil compteur
    cursor.execute("UPDATE meters SET threshold_kwh=%s WHERE user_id=%s", (kwh, user_id))

    conn.commit()
    print(f"[✅] Facture générée : {kwh:.2f} kWh crédité pour {amount}$ (Seuil mis à jour)")

def check_threshold():
    user_id = int(input("ID de l'utilisateur : "))
    cursor.execute("SELECT meter_number, threshold_kwh FROM meters WHERE user_id=%s", (user_id,))
    result = cursor.fetchone()
    if result:
        meter_number, threshold = result
        print(f"[ℹ️] Compteur '{meter_number}' - Seuil disponible : {threshold:.2f} kWh")
    else:
        print("[❌] Aucun compteur trouvé pour cet utilisateur.")

# ---------------------- Menu ----------------------

def main():
    while True:
        print("\n=== Système de gestion de seuil énergétique ===")
        print("1. Ajouter un utilisateur")
        print("2. Payer pour augmenter le seuil")
        print("3. Vérifier le seuil restant")
        print("0. Quitter")

        choice = input("Choix : ")

        if choice == "1":
            add_user()
        elif choice == "2":
            pay_amount()
        elif choice == "3":
            check_threshold()
        elif choice == "0":
            break
        else:
            print("[❌] Choix invalide, réessayez.")

if __name__ == "__main__":
    main()

cursor.close()
conn.close()
