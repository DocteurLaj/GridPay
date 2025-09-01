import json
import sqlite3
import paho.mqtt.client as mqtt
from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_bcrypt import Bcrypt
from datetime import timedelta, datetime
import re
import threading
import time

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = 'ton_secret_key_très_long_et_complexe_en_production'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=1)

# Initialisation des extensions
jwt = JWTManager(app)
bcrypt = Bcrypt(app)


BROKER = "broker.hivemq.com"
PORT = 8884  # TLS sécurisé
mqtt_client = None
mqtt_topics = []



#-----------------------------------------------------------------------------------------------
#                                  INITIALISATION BASE DE DONNÉES                                      
# ---------------------------------------------------------------------------------------------

def init_db():
    """Initialise la base de données avec la table users"""
    conn = sqlite3.connect('gridpay.db')
    cursor = conn.cursor()
    
    # Création des tables si elle n'exist pas
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            phone TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
       CREATE TABLE IF NOT EXISTS meters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            meter_number TEXT UNIQUE NOT NULL,
            meter_name TEXT,
            status TEXT DEFAULT 'active',
            cumulative_consumption REAL DEFAULT 0.0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            meter_id INTEGER NOT NULL,
            month TEXT NOT NULL,              
            amount REAL NOT NULL,
            status TEXT DEFAULT 'unpaid',
            kwh INTEGER NOT NULL,
            issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (meter_id) REFERENCES meters(id) ON DELETE CASCADE
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            payment_method TEXT NOT NULL,
            transaction_id TEXT UNIQUE,
            status TEXT DEFAULT 'completed',
            paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        )
    ''')
    
    
    conn.commit()
    conn.close()

# Initialiser la base au démarrage
init_db()

#-----------------------------------------------------------------------------------------------
#                                  AUTH                                      
# ---------------------------------------------------------------------------------------------

def is_valid_email(email):
    """Valide le format de l'email"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'message': 'Données JSON requises'}), 400
        
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return jsonify({'message': 'Email et mot de passe requis'}), 400
        
        if not is_valid_email(email):
            return jsonify({'message': 'Format d\'email invalide'}), 400
        
        # Vérification dans la base de données - CORRECTION: Sélectionner tous les champs
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, email, password, phone, created_at FROM users WHERE email=?", (email,))
        user = cursor.fetchone()
        conn.close()

        if user:
            user_id, name, user_email, hashed_password, phone, created_at = user
            
            # Vérification du mot de passe AVEC FLASK-BCRYPT
            if bcrypt.check_password_hash(hashed_password, password):
                token = create_access_token(identity=user_email)
                
                # CORRECTION: Renvoyer toutes les informations utilisateur
                return jsonify({
                    'token': token,
                    'user_id': user_id,
                    'email': user_email,
                    'name': name,
                    'phone': phone,
                    'created_at': created_at
                }), 200
            else:
                return jsonify({'message': 'Email ou mot de passe incorrect'}), 401
        else:
            return jsonify({'message': 'Email ou mot de passe incorrect'}), 401
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

# ---------------- REGISTER CORRIGÉ ----------------------- 

@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        phone = data.get('phone')
        name = data.get('name')
        
        if not email or not password or not phone or not name:
            return jsonify({'message': 'Email, mot de passe, phone et nom requis'}), 400
        
        if not is_valid_email(email):
            return jsonify({'message': 'Format d\'email invalide'}), 400
        
        if len(password) < 8:
            return jsonify({'message': 'Le mot de passe doit faire au moins 8 caractères'}), 400
        
        # Hachage du mot de passe AVEC FLASK-BCRYPT
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier si l'email existe déjà
        cursor.execute("SELECT id FROM users WHERE email=?", (email,))
        if cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Cet email est déjà utilisé'}), 409
        
        # Vérifier si le numéro de téléphone existe déjà
        cursor.execute("SELECT id FROM users WHERE phone=?", (phone,))
        if cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Ce numéro de téléphone est déjà utilisé'}), 409
        
        # Insérer le nouvel utilisateur
        cursor.execute(
            "INSERT INTO users (email, password, phone, name) VALUES (?, ?, ?, ?)",
            (email, hashed_password, phone, name)
        )
        conn.commit()
        
        # Récupérer toutes les informations de l'utilisateur créé - CORRECTION
        cursor.execute("SELECT id, name, email, phone, created_at FROM users WHERE id=?", (cursor.lastrowid,))
        new_user = cursor.fetchone()
        conn.close()
        
        if new_user:
            user_id, name, email, phone, created_at = new_user
            return jsonify({
                'message': 'Utilisateur créé avec succès',
                'user_id': user_id,
                'name': name,
                'email': email,
                'phone': phone,
                'created_at': created_at
            }), 201
        else:
            return jsonify({'message': 'Utilisateur créé mais erreur de récupération'}), 201
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500
    
def init_mqtt_for_user_auto(user_email):
    """Réinitialise automatiquement MQTT pour tous les compteurs d'un utilisateur"""
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer tous les compteurs de l'utilisateur
        cursor.execute("""
            SELECT meter_number 
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE u.email = ?
        """, (user_email,))
        
        meters = cursor.fetchall()
        conn.close()
        
        if meters:
            # Créer les topics pour tous les compteurs
            consumption_topics = [f"electricity/{meter[0]}/consumption" for meter in meters]
            relay_topics = [f"electricity/{meter[0]}/relay" for meter in meters]
            
            all_topics = consumption_topics + relay_topics
            
            # Réinitialiser MQTT avec tous ces topics
            init_mqtt(all_topics)
            print(f"[MQTT AUTO] Réinitialisé pour {len(meters)} compteurs de {user_email}")
        
    except Exception as e:
        print(f"[MQTT AUTO ERROR] Erreur réinitialisation automatique: {e}")

#------------------------------------------------------------------------------------------------
#                                      GESTION DU COMPTUER
#------------------------------------------------------------------------------------------------
# -------------------- GESTION DES COMPTEURS (METERS) --------------------

@app.route('/meters', methods=['GET'])
@jwt_required()
def get_user_meters():
    """Récupère tous les compteurs de l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # -----------Récupérer l'ID de l'utilisateur-----------
        cursor.execute("SELECT id FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
        
        user_id = user[0]
        
        # ---------Récupérer tous les compteurs de l'utilisateur----------
        cursor.execute("""
            SELECT id, meter_number, meter_name, status, created_at, updated_at 
            FROM meters 
            WHERE user_id=?
            ORDER BY created_at DESC
        """, (user_id,))
        
        meters = cursor.fetchall()
        conn.close()
        
        #------ Formater les résultats -------
        meters_list = []
        for meter in meters:
            meters_list.append({
                'id': meter[0],
                'meter_number': meter[1],
                'meter_name': meter[2],
                'status': meter[3],
                'created_at': meter[4],
                'updated_at': meter[5]
            })
        
        return jsonify({'meters': meters_list}), 200
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/meters', methods=['POST'])
@jwt_required()
def add_meter():
    """Ajoute un nouveau compteur pour l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        data = request.get_json()
        
        if not data:
            return jsonify({'message': 'Données JSON requises'}), 400
        
        meter_number = data.get('meter_number')
        meter_name = data.get('meter_name', '')
        
        if not meter_number:
            return jsonify({'message': 'Le numéro de compteur est requis'}), 400
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # -----Récupérer l'ID de l'utilisateur--------
        cursor.execute("SELECT id FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
        
        user_id = user[0]
        
        # ----------Vérifier si le compteur existe déjà-------
        cursor.execute("SELECT id FROM meters WHERE meter_number=?", (meter_number,))
        if cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Ce numéro de compteur est déjà utilisé'}), 409
        
        #----------- Ajouter le nouveau compteur----
        cursor.execute("""
            INSERT INTO meters (user_id, meter_number, meter_name) 
            VALUES (?, ?, ?)
        """, (user_id, meter_number, meter_name))
        
        conn.commit()
        
        #------------ Récupérer les détails du compteur créé-----
        cursor.execute("""
            SELECT id, meter_number, meter_name, status, created_at, updated_at 
            FROM meters 
            WHERE id=?
        """, (cursor.lastrowid,))
        
        new_meter = cursor.fetchone()
        conn.close()
        
        if new_meter:
            # Après avoir ajouté le compteur, réinitialiser MQTT
            init_mqtt_for_user_auto(user_email)  # ← ASSUREZ-VOUS QUE CETTE FONCTION EXISTE
            return jsonify({
                'message': 'Compteur ajouté avec succès',
                'meter': {
                    'id': new_meter[0],
                    'meter_number': new_meter[1],
                    'meter_name': new_meter[2],
                    'status': new_meter[3],
                    'created_at': new_meter[4],
                    'updated_at': new_meter[5]
                }
            }), 201
        else:
            return jsonify({'message': 'Compteur créé mais erreur de récupération'}), 201
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500
    
@app.route('/meters/<int:meter_id>', methods=['PUT'])
@jwt_required()
def update_meter(meter_id):
    """Modifie un compteur existant de l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        data = request.get_json()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        #-------------Récupérer l'ID de l'utilisateur-----------
        cursor.execute("SELECT id FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
        
        user_id = user[0]
        
        # ------------Vérifier que le compteur appartient à l'utilisateur--------
        cursor.execute("SELECT id FROM meters WHERE id=? AND user_id=?", (meter_id, user_id))
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        # ---------Préparer la requête de mise à jour---------
        update_fields = []
        update_values = []
        
        if 'meter_name' in data:
            update_fields.append("meter_name = ?")
            update_values.append(data['meter_name'])
        
        if 'status' in data:
            update_fields.append("status = ?")
            update_values.append(data['status'])
        
        if not update_fields:
            conn.close()
            return jsonify({'message': 'Aucune donnée à mettre à jour'}), 400
        
        # -----------Ajouter la date de mise à jour-------------
        update_fields.append("updated_at = CURRENT_TIMESTAMP")
        update_values.append(meter_id)
        
        # ----------Exécuter la mise à jour---------------
        cursor.execute(f"""
            UPDATE meters 
            SET {', '.join(update_fields)}
            WHERE id = ?
        """, update_values)
        
        conn.commit()
        
        # -----------Récupérer le compteur mis à jour-------------
        cursor.execute("""
            SELECT id, meter_number, meter_name, status, created_at, updated_at 
            FROM meters 
            WHERE id=?
        """, (meter_id,))
        
        updated_meter = cursor.fetchone()
        conn.close()
        
        if updated_meter:
            return jsonify({
                'message': 'Compteur mis à jour avec succès',
                'meter': {
                    'id': updated_meter[0],
                    'meter_number': updated_meter[1],
                    'meter_name': updated_meter[2],
                    'status': updated_meter[3],
                    'created_at': updated_meter[4],
                    'updated_at': updated_meter[5]
                }
            }), 200
        else:
            return jsonify({'message': 'Erreur lors de la récupération du compteur mis à jour'}), 500
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/meters/<int:meter_id>', methods=['DELETE'])
@jwt_required()
def delete_meter(meter_id):
    """Supprime un compteur de l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        #----------- Récupérer l'ID de l'utilisateur------------
        cursor.execute("SELECT id FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
        
        user_id = user[0]
        
        # -----------Vérifier que le compteur appartient à l'utilisateur------------
        cursor.execute("SELECT id FROM meters WHERE id=? AND user_id=?", (meter_id, user_id))
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        #--------- --Supprimer le compteur------------
        cursor.execute("DELETE FROM meters WHERE id=?", (meter_id,))
        conn.commit()
        conn.close()
        
        return jsonify({'message': 'Compteur supprimé avec succès'}), 200
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/meters/<int:meter_id>', methods=['GET'])
@jwt_required()
def get_meter(meter_id):
    """Récupère les détails d'un compteur spécifique"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        #------------ Récupérer l'ID de l'utilisateur -------------

        cursor.execute("SELECT id FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
        
        user_id = user[0]
        
        # ------------- Récupérer le compteur -----------
        cursor.execute("""
            SELECT id, meter_number, meter_name, status, created_at, updated_at 
            FROM meters 
            WHERE id=? AND user_id=?
        """, (meter_id, user_id))
        
        meter = cursor.fetchone()
        conn.close()
        
        if meter:
            return jsonify({
                'meter': {
                    'id': meter[0],
                    'meter_number': meter[1],
                    'meter_name': meter[2],
                    'status': meter[3],
                    'created_at': meter[4],
                    'updated_at': meter[5]
                }
            }), 200
        else:
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500
    


#------------------------------------------------------------------------------------------------
#                                      GESTION DES FACTURES
#------------------------------------------------------------------------------------------------

@app.route('/invoices', methods=['GET'])
@jwt_required()
def get_user_invoices():
    """Récupère toutes les factures de l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer l'ID de l'utilisateur
        cursor.execute("SELECT id FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        
        if not user:
            conn.close()
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
        
        user_id = user[0]
        
        # Récupérer toutes les factures de l'utilisateur avec les infos du compteur
        cursor.execute("""
            SELECT i.id, i.meter_id, m.meter_number, m.meter_name, 
                   i.month, i.amount, i.status, i.kwh, i.issued_at
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            WHERE m.user_id = ?
            ORDER BY i.issued_at DESC
        """, (user_id,))
        
        invoices = cursor.fetchall()
        conn.close()
        
        # Formater les résultats
        invoices_list = []
        for invoice in invoices:
            invoices_list.append({
                'id': invoice[0],
                'meter_id': invoice[1],
                'meter_number': invoice[2],
                'meter_name': invoice[3],
                'month': invoice[4],
                'amount': invoice[5],
                'status': invoice[6],
                'kwh': invoice[7],
                'issued_at': invoice[8]
            })
        
        return jsonify({'invoices': invoices_list}), 200
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/invoices', methods=['POST'])
@jwt_required()
def add_invoice():
    """Ajoute une nouvelle facture"""
    try:
        user_email = get_jwt_identity()
        data = request.get_json()
        
        if not data:
            return jsonify({'message': 'Données JSON requises'}), 400
        
        meter_id = data.get('meter_id')
        month = data.get('month')
        amount = data.get('amount')
        kwh = data.get('kwh')
        status = data.get('status', 'unpaid')
        
        # Validation des données requises
        if not all([meter_id, month, amount, kwh]):
            return jsonify({'message': 'Tous les champs obligatoires sont requis'}), 400
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que le compteur appartient à l'utilisateur
        cursor.execute("""
            SELECT m.id 
            FROM meters m 
            JOIN users u ON m.user_id = u.id 
            WHERE m.id = ? AND u.email = ?
        """, (meter_id, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        # Vérifier si une facture existe déjà pour ce mois et ce compteur
        cursor.execute("""
            SELECT id FROM invoices 
            WHERE meter_id = ? AND month = ?
        """, (meter_id, month))
        
        if cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Une facture existe déjà pour ce mois et ce compteur'}), 409
        
        # Ajouter la nouvelle facture
        cursor.execute("""
            INSERT INTO invoices (meter_id, month, amount, status, kwh) 
            VALUES (?, ?, ?, ?, ?)
        """, (meter_id, month, amount, status, kwh))
        
        conn.commit()
        
        # Récupérer les détails de la facture créée
        cursor.execute("""
            SELECT i.id, i.meter_id, m.meter_number, m.meter_name, 
                   i.month, i.amount, i.status, i.kwh, i.issued_at
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            WHERE i.id = ?
        """, (cursor.lastrowid,))
        
        new_invoice = cursor.fetchone()
        conn.close()
        
        if new_invoice:
            return jsonify({
                'message': 'Facture ajoutée avec succès',
                'invoice': {
                    'id': new_invoice[0],
                    'meter_id': new_invoice[1],
                    'meter_number': new_invoice[2],
                    'meter_name': new_invoice[3],
                    'month': new_invoice[4],
                    'amount': new_invoice[5],
                    'status': new_invoice[6],
                    'kwh': new_invoice[7],
                    'issued_at': new_invoice[8]
                }
            }), 201
        else:
            return jsonify({'message': 'Facture créée mais erreur de récupération'}), 201
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/invoices/<int:invoice_id>', methods=['PUT'])
@jwt_required()
def update_invoice(invoice_id):
    """Modifie une facture existante"""
    try:
        user_email = get_jwt_identity()
        data = request.get_json()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que la facture appartient à l'utilisateur
        cursor.execute("""
            SELECT i.id 
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE i.id = ? AND u.email = ?
        """, (invoice_id, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Facture non trouvée ou accès non autorisé'}), 404
        
        # Préparer la requête de mise à jour
        update_fields = []
        update_values = []
        
        if 'amount' in data:
            update_fields.append("amount = ?")
            update_values.append(data['amount'])
        
        if 'status' in data:
            update_fields.append("status = ?")
            update_values.append(data['status'])
        
        if 'kwh' in data:
            update_fields.append("kwh = ?")
            update_values.append(data['kwh'])
        
        if 'month' in data:
            update_fields.append("month = ?")
            update_values.append(data['month'])
        
        if not update_fields:
            conn.close()
            return jsonify({'message': 'Aucune donnée à mettre à jour'}), 400
        
        update_values.append(invoice_id)
        
        # Exécuter la mise à jour
        cursor.execute(f"""
            UPDATE invoices 
            SET {', '.join(update_fields)}
            WHERE id = ?
        """, update_values)
        
        conn.commit()
        
        # Récupérer la facture mise à jour
        cursor.execute("""
            SELECT i.id, i.meter_id, m.meter_number, m.meter_name, 
                   i.month, i.amount, i.status, i.kwh, i.issued_at
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            WHERE i.id = ?
        """, (invoice_id,))
        
        updated_invoice = cursor.fetchone()
        conn.close()
        
        if updated_invoice:
            return jsonify({
                'message': 'Facture mise à jour avec succès',
                'invoice': {
                    'id': updated_invoice[0],
                    'meter_id': updated_invoice[1],
                    'meter_number': updated_invoice[2],
                    'meter_name': updated_invoice[3],
                    'month': updated_invoice[4],
                    'amount': updated_invoice[5],
                    'status': updated_invoice[6],
                    'kwh': updated_invoice[7],
                    'issued_at': updated_invoice[8]
                }
            }), 200
        else:
            return jsonify({'message': 'Erreur lors de la récupération de la facture mise à jour'}), 500
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/invoices/<int:invoice_id>', methods=['DELETE'])
@jwt_required()
def delete_invoice(invoice_id):
    """Supprime une facture"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que la facture appartient à l'utilisateur
        cursor.execute("""
            SELECT i.id 
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE i.id = ? AND u.email = ?
        """, (invoice_id, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Facture non trouvée ou accès non autorisé'}), 404
        
        # Supprimer la facture
        cursor.execute("DELETE FROM invoices WHERE id=?", (invoice_id,))
        conn.commit()
        conn.close()
        
        return jsonify({'message': 'Facture supprimée avec succès'}), 200
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/invoices/<int:invoice_id>', methods=['GET'])
@jwt_required()
def get_invoice(invoice_id):
    """Récupère les détails d'une facture spécifique"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer la facture avec vérification de propriété
        cursor.execute("""
            SELECT i.id, i.meter_id, m.meter_number, m.meter_name, 
                   i.month, i.amount, i.status, i.kwh, i.issued_at
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE i.id = ? AND u.email = ?
        """, (invoice_id, user_email))
        
        invoice = cursor.fetchone()
        conn.close()
        
        if invoice:
            return jsonify({
                'invoice': {
                    'id': invoice[0],
                    'meter_id': invoice[1],
                    'meter_number': invoice[2],
                    'meter_name': invoice[3],
                    'month': invoice[4],
                    'amount': invoice[5],
                    'status': invoice[6],
                    'kwh': invoice[7],
                    'issued_at': invoice[8]
                }
            }), 200
        else:
            return jsonify({'message': 'Facture non trouvée ou accès non autorisé'}), 404
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/meters/<int:meter_id>/invoices', methods=['GET'])
@jwt_required()
def get_meter_invoices(meter_id):
    """Récupère toutes les factures d'un compteur spécifique"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que le compteur appartient à l'utilisateur
        cursor.execute("""
            SELECT m.id 
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE m.id = ? AND u.email = ?
        """, (meter_id, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        # Récupérer les factures du compteur
        cursor.execute("""
            SELECT id, month, amount, status, kwh, issued_at
            FROM invoices 
            WHERE meter_id = ?
            ORDER BY issued_at DESC
        """, (meter_id,))
        
        invoices = cursor.fetchall()
        conn.close()
        
        # Formater les résultats
        invoices_list = []
        for invoice in invoices:
            invoices_list.append({
                'id': invoice[0],
                'month': invoice[1],
                'amount': invoice[2],
                'status': invoice[3],
                'kwh': invoice[4],
                'issued_at': invoice[5]
            })
        
        return jsonify({'invoices': invoices_list}), 200
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500






#------------------------------------------------------------------------------------------------
#                                      GESTION DES PAIEMENTS
#------------------------------------------------------------------------------------------------
@app.route('/payments', methods=['POST'])
@jwt_required()
def add_payment():
    """Ajoute un nouveau paiement pour une facture et envoie la commande ON"""
    try:
        user_email = get_jwt_identity()
        data = request.get_json()
        
        if not data:
            return jsonify({'message': 'Données JSON requises'}), 400
        
        invoice_id = data.get('invoice_id')
        amount = data.get('amount')
        payment_method = data.get('payment_method')
        transaction_id = data.get('transaction_id')
        
        # Validation des données requises
        if not all([invoice_id, amount, payment_method]):
            return jsonify({'message': 'invoice_id, amount et payment_method sont requis'}), 400
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que la facture appartient à l'utilisateur et récupérer les infos
        cursor.execute("""
            SELECT i.id, i.amount, i.status, i.meter_id, m.meter_number
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE i.id = ? AND u.email = ?
        """, (invoice_id, user_email))
        
        invoice = cursor.fetchone()
        
        if not invoice:
            conn.close()
            return jsonify({'message': 'Facture non trouvée ou accès non autorisé'}), 404
        
        invoice_db_id, invoice_amount, invoice_status, meter_id, meter_number = invoice
        
        # Vérifier que le montant du paiement est valide
        if float(amount) <= 0:
            conn.close()
            return jsonify({'message': 'Le montant du paiement doit être positif'}), 400
        
        # Vérifier si un paiement avec ce transaction_id existe déjà
        if transaction_id:
            cursor.execute("SELECT id FROM payments WHERE transaction_id=?", (transaction_id,))
            if cursor.fetchone():
                conn.close()
                return jsonify({'message': 'Un paiement avec ce transaction_id existe déjà'}), 409
        
        # Ajouter le nouveau paiement
        cursor.execute("""
            INSERT INTO payments (invoice_id, amount, payment_method, transaction_id) 
            VALUES (?, ?, ?, ?)
        """, (invoice_id, amount, payment_method, transaction_id))
        
        # Mettre à jour le statut de la facture si le paiement est complet
        payment_complete = False
        if float(amount) >= float(invoice_amount):
            cursor.execute("UPDATE invoices SET status = 'paid' WHERE id = ?", (invoice_id,))
            payment_complete = True
        
        conn.commit()
        
        # Récupérer les détails du paiement créé
        cursor.execute("""
            SELECT p.id, p.invoice_id, p.amount, p.payment_method, 
                   p.transaction_id, p.status, p.paid_at,
                   i.amount as invoice_amount
            FROM payments p
            JOIN invoices i ON p.invoice_id = i.id
            WHERE p.id = ?
        """, (cursor.lastrowid,))
        
        new_payment = cursor.fetchone()
        
        # ----------------------------------------------------------------
        # ENVOI DE LA COMMANDE ON AU BROKER MQTT SI PAIEMENT COMPLET
        # ----------------------------------------------------------------
        command_sent = False
        if payment_complete and meter_number:
            command = "ON"
            if send_mqtt_command(meter_number, command):
                print(f"[PAYMENT] Commande {command} envoyée pour le compteur {meter_number}")
                command_sent = True
            else:
                print(f"[PAYMENT ERROR] Échec envoi commande pour {meter_number}")
        
        conn.close()
        # ----------------------------------------------------------------
        
        if new_payment:
            return jsonify({
                'message': 'Paiement ajouté avec succès',
                'payment': {
                    'id': new_payment[0],
                    'invoice_id': new_payment[1],
                    'amount': new_payment[2],
                    'payment_method': new_payment[3],
                    'transaction_id': new_payment[4],
                    'status': new_payment[5],
                    'paid_at': new_payment[6],
                    'invoice_amount': new_payment[7]
                },
                'command_sent': command_sent,
                'meter_number': meter_number if command_sent else None
            }), 201
        else:
            return jsonify({'message': 'Paiement créé mais erreur de récupération'}), 201
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/payments', methods=['GET'])
@jwt_required()
def get_user_payments():
    """Récupère tous les paiements de l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer tous les paiements de l'utilisateur avec les infos des factures
        cursor.execute("""
            SELECT p.id, p.invoice_id, p.amount, p.payment_method, 
                   p.transaction_id, p.status, p.paid_at,
                   i.amount as invoice_amount, i.month, i.status as invoice_status,
                   m.meter_number, m.meter_name
            FROM payments p
            JOIN invoices i ON p.invoice_id = i.id
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE u.email = ?
            ORDER BY p.paid_at DESC
        """, (user_email,))
        
        payments = cursor.fetchall()
        conn.close()
        
        # Formater les résultats
        payments_list = []
        for payment in payments:
            payments_list.append({
                'id': payment[0],
                'invoice_id': payment[1],
                'amount': payment[2],
                'payment_method': payment[3],
                'transaction_id': payment[4],
                'status': payment[5],
                'paid_at': payment[6],
                'invoice_amount': payment[7],
                'invoice_month': payment[8],
                'invoice_status': payment[9],
                'meter_number': payment[10],
                'meter_name': payment[11]
            })
        
        return jsonify({'payments': payments_list}), 200
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/invoices/<int:invoice_id>/payments', methods=['GET'])
@jwt_required()
def get_invoice_payments(invoice_id):
    """Récupère tous les paiements d'une facture spécifique"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que la facture appartient à l'utilisateur
        cursor.execute("""
            SELECT i.id 
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE i.id = ? AND u.email = ?
        """, (invoice_id, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Facture non trouvée ou accès non autorisé'}), 404
        
        # Récupérer les paiements de la facture
        cursor.execute("""
            SELECT id, amount, payment_method, transaction_id, status, paid_at
            FROM payments 
            WHERE invoice_id = ?
            ORDER BY paid_at DESC
        """, (invoice_id,))
        
        payments = cursor.fetchall()
        conn.close()
        
        # Formater les résultats
        payments_list = []
        for payment in payments:
            payments_list.append({
                'id': payment[0],
                'amount': payment[1],
                'payment_method': payment[2],
                'transaction_id': payment[3],
                'status': payment[4],
                'paid_at': payment[5]
            })
        
        return jsonify({'payments': payments_list}), 200
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/payments/<int:payment_id>', methods=['GET'])
@jwt_required()
def get_payment(payment_id):
    """Récupère les détails d'un paiement spécifique"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer le paiement avec vérification de propriété
        cursor.execute("""
            SELECT p.id, p.invoice_id, p.amount, p.payment_method, 
                   p.transaction_id, p.status, p.paid_at,
                   i.amount as invoice_amount, i.month, i.status as invoice_status,
                   m.meter_number, m.meter_name
            FROM payments p
            JOIN invoices i ON p.invoice_id = i.id
            JOIN meters m ON i.meter_id = m.id
            JOIN users u ON m.user_id = u.id
            WHERE p.id = ? AND u.email = ?
        """, (payment_id, user_email))
        
        payment = cursor.fetchone()
        conn.close()
        
        if payment:
            return jsonify({
                'payment': {
                    'id': payment[0],
                    'invoice_id': payment[1],
                    'amount': payment[2],
                    'payment_method': payment[3],
                    'transaction_id': payment[4],
                    'status': payment[5],
                    'paid_at': payment[6],
                    'invoice_amount': payment[7],
                    'invoice_month': payment[8],
                    'invoice_status': payment[9],
                    'meter_number': payment[10],
                    'meter_name': payment[11]
                }
            }), 200
        else:
            return jsonify({'message': 'Paiement non trouvé ou accès non autorisé'}), 404
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500
# -----------------------------------------------------------------------------------------------
# Traitement consommation avec vérification de seuil (sans modification de base)
# -----------------------------------------------------------------------------------------------
def process_consumption_data(data):
    """Traite les données de consommation et vérifie le seuil pour coupure automatique"""
    try:
        meter_number = data.get('meter_number')
        kwh = data.get('kwh', 0)
        
        # Vérifications initiales
        if not meter_number:
            print("[MQTT ERROR] Numéro de compteur manquant dans les données")
            return
        
        if not kwh:
            print("[MQTT ERROR] Valeur de consommation manquante")
            return
        
        # Convertir en float avec validation
        try:
            consumption = float(kwh)
            if consumption < 0:
                print(f"[MQTT ERROR] Consommation négative: {consumption}kWh")
                return
        except ValueError:
            print(f"[MQTT ERROR] Valeur de consommation invalide: {kwh}")
            return
        
        # Vérifier que le compteur existe ET appartient à un utilisateur actif
        if not is_valid_meter(meter_number):
            print(f"[MQTT WARNING] Compteur {meter_number} invalide ou inactif")
            return
        
        # Récupérer la consommation actuelle
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT cumulative_consumption 
            FROM meters 
            WHERE meter_number = ?
        """, (meter_number,))
        
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            print(f"[MQTT ERROR] Compteur {meter_number} non trouvé")
            return
        
        current_cumulative = result[0]
        new_cumulative = current_cumulative + consumption
        
        # Mettre à jour la consommation cumulative
        cursor.execute("""
            UPDATE meters 
            SET cumulative_consumption = ?, 
                updated_at = CURRENT_TIMESTAMP
            WHERE meter_number = ?
        """, (new_cumulative, meter_number))
        
        conn.commit()
        conn.close()
        
        print(f"[MQTT SUCCESS] Consommation enregistrée pour {meter_number}: {consumption}kWh, Total: {new_cumulative}kWh")
        
        # -----------------------------------------------------------------
        # VÉRIFICATION MANUELLE DU SEUIL (sans colonne energy_threshold)
        # On utilise un seuil fixe ou on récupère depuis les factures
        # -----------------------------------------------------------------
        energy_threshold = get_energy_threshold_for_meter(meter_number)
        
        if energy_threshold is not None and new_cumulative >= energy_threshold:
            print(f"[MQTT ALERT] Seuil atteint pour {meter_number}: {new_cumulative}/{energy_threshold}kWh")
            
            # Envoyer la commande OFF
            if send_mqtt_command(meter_number, "OFF"):
                print(f"[MQTT] Commande OFF envoyée automatiquement pour {meter_number}")
            else:
                print(f"[MQTT ERROR] Échec envoi commande OFF pour {meter_number}")
        
    except Exception as e:
        print(f"[MQTT ERROR] Erreur traitement données: {e}")

def get_energy_threshold_for_meter(meter_number):
    """Détermine le seuil d'énergie pour un compteur"""
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Méthode 1: Récupérer depuis la dernière facture payée
        cursor.execute("""
            SELECT i.kwh 
            FROM invoices i
            JOIN meters m ON i.meter_id = m.id
            WHERE m.meter_number = ? AND i.status = 'paid'
            ORDER BY i.issued_at DESC
            LIMIT 1
        """, (meter_number,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            # Utiliser le kwh de la dernière facture payée comme seuil
            return float(result[0])
        else:
            # Méthode 2: Seuil par défaut (100 kWh)
            return 100.0
            
    except Exception as e:
        print(f"[THRESHOLD ERROR] Erreur récupération seuil: {e}")
        return 100.0  # Seuil par défaut en cas d'erreur
    


# -----------------------------------------------------------------------------------------------
# Gestion des seuils d'énergie sans modification de la structure
# -----------------------------------------------------------------------------------------------

@app.route('/api/meters/<string:meter_number>/check_threshold', methods=['GET'])
@jwt_required()
def check_energy_threshold(meter_number):
    """Vérifie si la consommation a atteint le seuil"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que le compteur appartient à l'utilisateur
        cursor.execute("""
            SELECT m.id 
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE m.meter_number = ? AND u.email = ?
        """, (meter_number, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        # Récupérer la consommation cumulative
        cursor.execute("""
            SELECT cumulative_consumption 
            FROM meters 
            WHERE meter_number = ?
        """, (meter_number,))
        
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            return jsonify({'message': 'Erreur récupération consommation'}), 500
        
        current_consumption = result[0]
        energy_threshold = get_energy_threshold_for_meter(meter_number)
        
        conn.close()
        
        threshold_reached = current_consumption >= energy_threshold
        
        return jsonify({
            'meter_number': meter_number,
            'current_consumption': current_consumption,
            'energy_threshold': energy_threshold,
            'threshold_reached': threshold_reached,
            'remaining': energy_threshold - current_consumption if not threshold_reached else 0
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

@app.route('/api/meters/<string:meter_number>/send_command', methods=['POST'])
@jwt_required()
def send_meter_command():
    """Envoie une commande manuelle au compteur"""
    try:
        user_email = get_jwt_identity()
        data = request.get_json()
        
        if not data:
            return jsonify({'message': 'Données JSON requises'}), 400
        
        meter_number = data.get('meter_number')
        command = data.get('command')
        
        if not meter_number or not command:
            return jsonify({'message': 'Numéro de compteur et commande requis'}), 400
        
        if command not in ['ON', 'OFF']:
            return jsonify({'message': 'Commande invalide. Utilisez ON ou OFF'}), 400
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que le compteur appartient à l'utilisateur
        cursor.execute("""
            SELECT m.id 
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE m.meter_number = ? AND u.email = ?
        """, (meter_number, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        conn.close()
        
        # Envoyer la commande MQTT
        if send_mqtt_command(meter_number, command):
            # Si commande ON, réinitialiser la consommation cumulative
            if command == "ON":
                reset_cumulative_consumption(meter_number)
            
            return jsonify({
                'message': f'Commande {command} envoyée avec succès',
                'meter_number': meter_number
            }), 200
        else:
            return jsonify({'message': 'Erreur lors de l\'envoi de la commande'}), 500
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

def reset_cumulative_consumption(meter_number):
    """Réinitialise la consommation cumulative d'un compteur"""
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE meters 
            SET cumulative_consumption = 0.0 
            WHERE meter_number = ?
        """, (meter_number,))
        
        conn.commit()
        conn.close()
        print(f"[DB] Consommation réinitialisée pour {meter_number}")
        
    except Exception as e:
        print(f"[DB ERROR] Erreur réinitialisation consommation: {e}")









#-----------------------------------------------------------------------------------------------
#                                  FONCTIONS DE GESTION DE CONSOMMATION                                      
# ---------------------------------------------------------------------------------------------
def is_valid_meter(meter_number):
    """Vérifie si le compteur existe ET est actif"""
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, status 
            FROM meters 
            WHERE meter_number = ? AND status = 'active'
        """, (meter_number,))
        
        exists = cursor.fetchone() is not None
        conn.close()
        return exists
        
    except Exception as e:
        print(f"[DB ERROR] Erreur vérification compteur: {e}")
        return False
    
def add_consumption(meter_number, consumption):
    """Ajoute de la consommation de manière cumulative pour un compteur EXISTANT"""
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        cursor.execute("SELECT cumulative_consumption FROM meters WHERE meter_number = ?", (meter_number,))
        result = cursor.fetchone()
        
        if not result:
            conn.close()
            print(f"[DB ERROR] Compteur {meter_number} non trouvé lors de l'ajout")
            return False
        
        current_cumulative = result[0]
        new_cumulative = current_cumulative + consumption
        
        # Mettre à jour la consommation cumulative
        cursor.execute("""
            UPDATE meters 
            SET cumulative_consumption = ?, 
                updated_at = CURRENT_TIMESTAMP
            WHERE meter_number = ?
        """, (new_cumulative, meter_number))
        
        conn.commit()
        conn.close()
        
        print(f"[DB] Consommation ajoutée pour {meter_number}: {consumption}kWh, Total: {new_cumulative}kWh")
        
        # Vérifier automatiquement le seuil après chaque ajout
        energy_threshold = get_energy_threshold_for_meter(meter_number)
        if new_cumulative >= energy_threshold:
            print(f"[THRESHOLD] Seuil atteint! Envoi commande OFF pour {meter_number}")
            send_mqtt_command(meter_number, "OFF")
        
        return True
        
    except Exception as e:
        print(f"[DB ERROR] Erreur ajout consommation: {e}")
        return False

def get_cumulative_consumption(meter_number):
    """Récupère la consommation cumulative d'un compteur"""
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT cumulative_consumption 
            FROM meters 
            WHERE meter_number = ?
        """, (meter_number,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            return result[0]
        else:
            return None
            
    except Exception as e:
        print(f"[DB ERROR] Erreur récupération consommation: {e}")
        return None
#-----------------------------------------------------------------------------------------------
#                                  INITIALISATION MQTT                                      
# ---------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------
# Vérifier si un compteur existe en base
# -----------------------------------------------------------------------------------------------
def meter_exists(meter_number):
    conn = sqlite3.connect('gridpay.db')
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM meters WHERE meter_number = ?", (meter_number,))
    exists = cursor.fetchone() is not None
    conn.close()
    return exists


# -----------------------------------------------------------------------------------------------
# Callbacks MQTT
# -----------------------------------------------------------------------------------------------
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[MQTT] Connecté au broker avec succès")
        for topic in mqtt_topics:
            client.subscribe(topic)
            print(f"[MQTT] Abonné au topic: {topic}")
    else:
        print(f"[MQTT] Erreur de connexion: {rc}")


def on_message(client, userdata, msg):
    """Callback quand on reçoit des données de consommation MQTT"""
    try:
        payload = msg.payload.decode()
        data = json.loads(payload)

        # Extraire le numéro de compteur du topic
        topic_parts = msg.topic.split('/')
        if len(topic_parts) >= 2:
            meter_number = topic_parts[1]  # electricity/{meter_number}/consumption
            data['meter_number'] = meter_number

        print(f"[MQTT] Données reçues sur {msg.topic}: {data}")

        # Traiter les données de consommation
        process_consumption_data(data)

    except Exception as e:
        print(f"[MQTT ERROR] Erreur traitement: {e}")


# -----------------------------------------------------------------------------------------------
# Traitement consommation
# -----------------------------------------------------------------------------------------------
def process_consumption_data(data):
    """Traite les données de consommation et les stocke en base"""
    try:
        meter_number = data.get('meter_number')
        kwh = data.get('kwh', 0)
        
        # Vérifications initiales
        if not meter_number:
            print("[MQTT ERROR] Numéro de compteur manquant dans les données")
            return
        
        if not kwh:
            print("[MQTT ERROR] Valeur de consommation manquante")
            return
        
        # Convertir en float avec validation
        try:
            consumption = float(kwh)
            if consumption < 0:
                print(f"[MQTT ERROR] Consommation négative: {consumption}kWh")
                return
        except ValueError:
            print(f"[MQTT ERROR] Valeur de consommation invalide: {kwh}")
            return
        
        # ➡️ Vérifier que le compteur existe ET appartient à un utilisateur actif
        if not is_valid_meter(meter_number):

            print(f"[MQTT WARNING] Compteur {meter_number} invalide ou inactif")
            return
        
        # ➡️ Ajouter la consommation (sans re-vérification)
        if add_consumption(meter_number, consumption):
            print(f"[MQTT SUCCESS] Consommation enregistrée pour {meter_number}: {consumption}kWh")
        else:
            print(f"[MQTT ERROR] Échec enregistrement pour {meter_number}")
        
    except Exception as e:
        print(f"[MQTT ERROR] Erreur traitement données: {e}")

# -----------------------------------------------------------------------------------------------
# Initialisation MQTT
# -----------------------------------------------------------------------------------------------
def init_mqtt(topics):
    """Initialise et connecte le client MQTT avec une liste de topics"""
    global mqtt_client, mqtt_topics

    mqtt_topics = topics

    try:
        if mqtt_client:
            mqtt_client.loop_stop()
            mqtt_client.disconnect()

        mqtt_client = mqtt.Client(transport="websockets")
        mqtt_client.on_connect = on_connect
        mqtt_client.on_message = on_message

        # Activer TLS obligatoire pour PythonAnywhere (seuls 443/8883/8884 sortent)
        mqtt_client.tls_set()

        print(f"[MQTT] Connexion au broker {BROKER}:{PORT} pour {len(topics)} topics...")
        mqtt_client.connect(BROKER, PORT, 60)
        mqtt_client.loop_start()

    except Exception as e:
        print(f"[MQTT ERROR] Erreur initialisation: {e}")


# -----------------------------------------------------------------------------------------------
# Envoi de commandes (ON/OFF)
# -----------------------------------------------------------------------------------------------
def send_mqtt_command(meter_number, command):
    """Envoie une commande ON/OFF via MQTT pour un compteur spécifique"""
    global mqtt_client

    if mqtt_client:
        try:
            topic = f"electricity/{meter_number}/relay"
            message = {"command": command}
            mqtt_client.publish(topic, json.dumps(message))
            print(f"[MQTT] Commande {command} envoyée sur {topic}")
            return True
        except Exception as e:
            print(f"[MQTT ERROR] Erreur envoi commande: {e}")
            return False
    else:
        print("[MQTT ERROR] Client MQTT non initialisé")
        return False

#-----------------------------------------------------------------------------------------------
#                                  ROUTES API                                      
# ---------------------------------------------------------------------------------------------

@app.route('/api/meters/<string:meter_number>/cumulative_consumption', methods=['GET'])
@jwt_required()
def get_cumulative_consumption_route(meter_number):
    """Récupère la consommation cumulative d'un compteur"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Vérifier que le compteur appartient à l'utilisateur
        cursor.execute("""
            SELECT m.id, m.meter_name
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE m.meter_number = ? AND u.email = ?
        """, (meter_number, user_email))
        
        meter = cursor.fetchone()
        
        if not meter:
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        meter_id, meter_name = meter
        
        # Récupérer la consommation cumulative
        cumulative_consumption = get_cumulative_consumption(meter_number)
        
        if cumulative_consumption is None:
            conn.close()
            return jsonify({'message': 'Erreur lors de la récupération de la consommation'}), 500
        
        conn.close()
        
        return jsonify({
            'meter_number': meter_number,
            'meter_name': meter_name,
            'cumulative_consumption': cumulative_consumption
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500
    

@app.route('/api/mqtt/command', methods=['POST'])
@jwt_required()
def send_command():
    """Envoie une commande ON/OFF au compteur via MQTT"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'message': 'Données JSON requises'}), 400
        
        command = data.get('command')
        meter_number = data.get('meter_number')  # Doit être spécifié
        
        if not meter_number:
            return jsonify({'message': 'Numéro de compteur requis'}), 400
        
        if command not in ['ON', 'OFF']:
            return jsonify({'message': 'Commande invalide. Utilisez ON ou OFF'}), 400
        
        # Vérifier que l'utilisateur possède ce compteur
        user_email = get_jwt_identity()
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT m.id 
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE m.meter_number = ? AND u.email = ?
        """, (meter_number, user_email))
        
        if not cursor.fetchone():
            conn.close()
            return jsonify({'message': 'Compteur non trouvé ou accès non autorisé'}), 404
        
        conn.close()
        
        # Envoyer la commande MQTT
        if send_mqtt_command(meter_number, command):
            return jsonify({
                'message': f'Commande {command} envoyée avec succès',
                'meter_number': meter_number,
                'topic': f"electricity/{meter_number}/relay"
            }), 200
        else:
            return jsonify({'message': 'Erreur lors de l\'envoi de la commande'}), 500
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500


@app.route('/api/mqtt/init', methods=['POST'])
@jwt_required()
def init_mqtt_for_user():
    """Initialise MQTT avec tous les compteurs de l'utilisateur connecté"""
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer tous les compteurs de l'utilisateur
        cursor.execute("""
            SELECT meter_number 
            FROM meters m
            JOIN users u ON m.user_id = u.id
            WHERE u.email = ?
        """, (user_email,))
        
        meters = cursor.fetchall()
        conn.close()
        
        if not meters:
            return jsonify({'message': 'Aucun compteur trouvé pour cet utilisateur'}), 404
        
        # Créer les topics pour tous les compteurs
        consumption_topics = [f"electricity/{meter[0]}/consumption" for meter in meters]
        relay_topics = [f"electricity/{meter[0]}/relay" for meter in meters]
        
        all_topics = consumption_topics + relay_topics
        
        # Initialiser MQTT avec tous ces topics
        init_mqtt(all_topics)
        
        return jsonify({
            'message': f'MQTT initialisé pour {len(meters)} compteurs',
            'meters': [meter[0] for meter in meters],
            'topics_consumption': consumption_topics,
            'topics_relay': relay_topics
        }), 200
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500



# ---------------- More -----------------------

# Route protégée exemple
@app.route('/protected', methods=['GET'])
@jwt_required()
def protected():
    current_user = get_jwt_identity()
    return jsonify({'message': f'Bienvenue {current_user}', 'user': current_user}), 200

# Endpoint pour récupérer les infos utilisateur
@app.route('/user/<int:user_id>', methods=['GET'])
@jwt_required()
def get_user(user_id):
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        cursor.execute("SELECT id, email, phone, name, created_at FROM users WHERE id=?", (user_id,))
        user = cursor.fetchone()
        conn.close()

        if user:
            return jsonify({
                'id': user[0],
                'email': user[1],
                'phone': user[2],
                'name': user[3],
                'created_at': user[4]
            }), 200
        else:
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

# Endpoint pour récupérer les infos de l'utilisateur connecté
@app.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    try:
        user_email = get_jwt_identity()
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, email, phone, created_at FROM users WHERE email=?", (user_email,))
        user = cursor.fetchone()
        conn.close()

        if user:
            return jsonify({
                'id': user[0],
                'name': user[1],
                'email': user[2],
                'phone': user[3],
                'created_at': user[4]
            }), 200
        else:
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500
    
def init_mqtt_at_startup():
    """Initialize MQTT for all users at application startup"""
    try:
        print("[MQTT] Initialisation au démarrage...")
        
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        
        # Récupérer tous les compteurs existants
        cursor.execute("SELECT meter_number FROM meters")
        meters = cursor.fetchall()
        conn.close()
        
        if meters:
            # Créer les topics pour tous les compteurs
            consumption_topics = [f"electricity/{meter[0]}/consumption" for meter in meters]
            relay_topics = [f"electricity/{meter[0]}/relay" for meter in meters]
            
            all_topics = consumption_topics + relay_topics
            
            # Initialiser MQTT
            init_mqtt(all_topics)
            print(f"[MQTT] ✅ Initialisé pour {len(meters)} compteurs au démarrage")
            print(f"[MQTT] 📡 Topics: {all_topics}")
        else:
            print("[MQTT] ⚠️ Aucun compteur trouvé pour l'initialisation")
            
    except Exception as e:
        print(f"[MQTT STARTUP ERROR] ❌ Erreur initialisation: {e}")

#-----------------------------------------------------------------------------------------------

    

#-----------------------------------------------------------------------------------------------
#                                  DÉMARRAGE DE L'APPLICATION                                      
# ---------------------------------------------------------------------------------------------

with app.app_context():
    print("Initialisation de l'application...")
    init_db()
    init_mqtt_at_startup()  # ← AJOUTEZ CETTE LIGNE


if __name__ == '__main__':
    # Démarrer l'API Flask
    app.run(debug=True, host='0.0.0.0', port=5000)

#if __name__ == '__main__':
#    app.run(debug=True) [SENT]