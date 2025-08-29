#-----------------------------------------------------------------------------------------------
#                                   ADD ENERGIE                                
# ---------------------------------------------------------------------------------------------~
def BayEnergy():

    #------------------------Calculer le montant-------------------------

    #------------------------FONCTION facturre --------------------------

    #------------------------FONCTION Payement ---------------------------
    #----------------------FONCTION SEND COMMENDE ON----------------------

    #------------------------ADD Seuil and Limite-------------------------

    pass





#-----------------------------------------------------------------------------------------------
#                                  VERIFICATION                                       
# ---------------------------------------------------------------------------------------------~
def Verify():

    #------------------------Select Seuil-------------------------
    #-------------------------Select Limite----------------------------

    """
    if Seuil > Limite {
        pass
    }else{
        FONCTION SEND COMMENDE OFF
    }
    """

    pass




#-----------------------------------------------------------------------------------------------
#                                   SEND COMMANDE                               
# ---------------------------------------------------------------------------------------------~
def SendCommand(on_or_off ):
    #--------------mqtt---------------
    pass




#-----------------------------------------------------------------------------------------------
#                                   MQTT  CONNECTION                               
# ---------------------------------------------------------------------------------------------~
def tetse():
    pass




#-----------------------------------------------------------------------------------------------
#                                   More FOCTIONE                               
# ---------------------------------------------------------------------------------------------~
def calculer_montant_energie(seuil_kwh, prix_par_kwh):
    """
    Calcule le montant à payer pour un seuil d'énergie donné.
    
    Args:
        seuil_kwh (float): Le seuil d'énergie en kWh choisi par l'utilisateur.
        prix_par_kwh (float): Le prix d'un kWh en monnaie locale.
        
    Returns:
        float: Montant total à payer.
    """
    if seuil_kwh < 0 or prix_par_kwh < 0:
        raise ValueError("Le seuil et le prix doivent être positifs")
    
    montant = seuil_kwh * prix_par_kwh
    return round(montant, 2)  # arrondi à 2 décimales


def pay_amount():
    user_id = int(input("ID de l'utilisateur : "))
    
    # Vérifier utilisateur
    cursor.execute("SELECT id FROM users WHERE id=?", (user_id,))
    if not cursor.fetchone():
        print("[❌] Utilisateur non trouvé.")
        return

    amount = float(input("Montant à payer ($) : "))
    kwh = amount / PRICE_PER_KWH
    threshold_date = datetime.now().isoformat(" ")

    # Créer facture
    cursor.execute(
        "INSERT INTO invoices (user_id, amount, kwh, threshold_date) VALUES (?, ?, ?, ?)",
        (user_id, amount, kwh, threshold_date)
    )
    invoice_id = cursor.lastrowid

    # Enregistrer paiement
    cursor.execute(
        "INSERT INTO payments (invoice_id, amount, payment_date) VALUES (?, ?, ?)",
        (invoice_id, amount, datetime.now().isoformat(" "))
    )

    # Mettre à jour seuil compteur
    cursor.execute("UPDATE meters SET threshold_kwh=? WHERE user_id=?", (kwh, user_id))

    conn.commit()
    print(f"[✅] Facture générée : {kwh:.2f} kWh crédité pour {amount}$ (Seuil mis à jour)")


def add_user():
    name = input("Nom de l'utilisateur : ")
    phone = input("Téléphone : ")
    meter_number = input("Numéro du compteur : ")
    cursor.execute("INSERT INTO users (name, phone) VALUES (?, ?)", (name, phone))
    user_id = cursor.lastrowid
    cursor.execute("INSERT INTO meters (user_id, meter_number) VALUES (?, ?)", (user_id, meter_number))
    conn.commit()
    print(f"[✅] Utilisateur '{name}' ajouté avec le compteur '{meter_number}' (ID: {user_id})")

