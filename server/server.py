from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_bcrypt import Bcrypt
import sqlite3
from datetime import timedelta
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
    
    # Création de la table users si elle n'existe pas
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            phone TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
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
        
        # Vérification dans la base de données
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        cursor.execute("SELECT id, email, password FROM users WHERE email=?", (email,))
        user = cursor.fetchone()
        conn.close()

        if user:
            user_id, user_email, hashed_password = user
            
            # Vérification du mot de passe AVEC FLASK-BCRYPT
            if bcrypt.check_password_hash(hashed_password, password):
                token = create_access_token(identity=user_email)
                return jsonify({
                    'token': token,
                    'user_id': user_id,
                    'email': user_email
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
        
        # CORRECTION: Supprimer le "not" devant phone
        if not email or not password or not phone:
            return jsonify({'message': 'Email, mot de passe et phone requis'}), 400
        
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
        
        # CORRECTION: Insérer avec le numéro de téléphone
        cursor.execute(
            "INSERT INTO users (email, password, phone) VALUES (?, ?, ?)",
            (email, hashed_password, phone)
        )
        conn.commit()
        
        # Récupérer l'ID de l'utilisateur créé
        user_id = cursor.lastrowid
        conn.close()
        
        return jsonify({
            'message': 'Utilisateur créé avec succès',
            'user_id': user_id
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

# ---------------- More -----------------------

# Route protégée exemple
@app.route('/protected', methods=['GET'])
@jwt_required()
def protected():
    current_user = get_jwt_identity()
    return jsonify({'message': f'Bienvenue {current_user}', 'user': current_user}), 200

# Exemple endpoint protégé
@app.route('/check_threshold', methods=['GET'])
@jwt_required()
def check_threshold():
    user_email = get_jwt_identity()
    # ici récupérer le seuil depuis la DB selon user_email
    threshold = 50  # exemple
    return jsonify({'email': user_email, 'threshold_kwh': threshold})

# Endpoint pour récupérer les infos utilisateur
@app.route('/user/<int:user_id>', methods=['GET'])
@jwt_required()
def get_user(user_id):
    try:
        conn = sqlite3.connect('gridpay.db')
        cursor = conn.cursor()
        cursor.execute("SELECT id, email, phone FROM users WHERE id=?", (user_id,))
        user = cursor.fetchone()
        conn.close()

        if user:
            return jsonify({
                'id': user[0],
                'email': user[1],
                'phone': user[2]
            }), 200
        else:
            return jsonify({'message': 'Utilisateur non trouvé'}), 404
            
    except Exception as e:
        return jsonify({'message': f'Erreur serveur: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True)