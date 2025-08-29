from flask import Flask, request, jsonify
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
import mysql.connector
from datetime import datetime, timedelta
import os

app = Flask(__name__)
bcrypt = Bcrypt(app)
app.config["JWT_SECRET_KEY"] = "ton_secret_jwt"  # à changer pour production
jwt = JWTManager(app)

# ---------------------- MySQL ----------------------
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "",
    "database": "gridpay"
}

PRICE_PER_KWH = 0.5

def get_db_connection():
    return mysql.connector.connect(**DB_CONFIG)

# ---------------------- Tables ----------------------
def create_tables():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT,
        password TEXT NOT NULL
                   
                   
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
    cursor.close()
    conn.close()

create_tables()

# ---------------------- Auth ----------------------
@app.route("/register", methods=["POST"])
def register():
    data = request.json
    name = data.get("name")
    phone = data.get("phone")
    password = data.get("password")
    meter_number = data.get("meter_number")

    conn = get_db_connection()
    cursor = conn.cursor()
    hashed = bcrypt.generate_password_hash(password).decode("utf-8")
    
    try:
        cursor.execute("INSERT INTO users (name, phone, password) VALUES (%s, %s, %s)", (name, phone, hashed))
        user_id = cursor.lastrowid
        cursor.execute("INSERT INTO meters (user_id, meter_number) VALUES (%s, %s)", (user_id, meter_number))
        conn.commit()
    except mysql.connector.Error as e:
        cursor.close()
        conn.close()
        return jsonify({"status": "error", "message": str(e)}), 400

    cursor.close()
    conn.close()
    return jsonify({"status": "success", "user_id": user_id})

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    phone = data.get("phone")
    password = data.get("password")

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, password FROM users WHERE phone=%s", (phone,))
    result = cursor.fetchone()
    cursor.close()
    conn.close()

    if result and bcrypt.check_password_hash(result[1], password):
        token = create_access_token(identity=result[0], expires_delta=timedelta(hours=12))
        return jsonify({"status": "success", "token": token})
    else:
        return jsonify({"status": "error", "message": "Identifiants incorrects"}), 401

# ---------------------- Paiement ----------------------
@app.route("/pay", methods=["POST"])
@jwt_required()
def pay_amount():
    user_id = get_jwt_identity()
    data = request.json
    amount = float(data.get("amount"))

    conn = get_db_connection()
    cursor = conn.cursor()
    
    kwh = amount / PRICE_PER_KWH
    threshold_date = datetime.now()

    cursor.execute(
        "INSERT INTO invoices (user_id, amount, kwh, threshold_date) VALUES (%s, %s, %s, %s)",
        (user_id, amount, kwh, threshold_date)
    )
    invoice_id = cursor.lastrowid

    cursor.execute(
        "INSERT INTO payments (invoice_id, amount, payment_date) VALUES (%s, %s, %s)",
        (invoice_id, amount, datetime.now())
    )

    cursor.execute("UPDATE meters SET threshold_kwh=%s WHERE user_id=%s", (kwh, user_id))
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"status": "success", "kwh": kwh, "amount": amount})

# ---------------------- Vérifier seuil ----------------------
@app.route("/check_threshold", methods=["GET"])
@jwt_required()
def check_threshold():
    user_id = get_jwt_identity()
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT meter_number, threshold_kwh FROM meters WHERE user_id=%s", (user_id,))
    result = cursor.fetchone()
    cursor.close()
    conn.close()

    if result:
        meter_number, threshold = result
        return jsonify({"meter_number": meter_number, "threshold_kwh": threshold})
    else:
        return jsonify({"status": "error", "message": "Utilisateur ou compteur non trouvé"}), 404

# ---------------------- Lancer l'API ----------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
