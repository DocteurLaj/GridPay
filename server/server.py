from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_bcrypt import Bcrypt
import sqlite3
from datetime import timedelta, datetime
import re

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = 'ton_secret_key_très_long_et_complexe_en_production'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=1)

# Initialisation des extensions
jwt = JWTManager(app)
bcrypt = Bcrypt(app)

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

if __name__ == '__main__':
    app.run(debug=True)