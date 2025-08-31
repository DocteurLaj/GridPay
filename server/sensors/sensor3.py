# sensor_simulator.py
import time
import json
import random
import paho.mqtt.client as mqtt

# === Configuration Broker MQTT ===
BROKER = "broker.hivemq.com"  
PORT = 1883
METER_NUMBER = "CNT-4521-4521"

# === Topics MQTT ===
TOPIC_CONSUMPTION = f"electricity/{METER_NUMBER}/consumption"
TOPIC_RELAY = f"electricity/{METER_NUMBER}/relay"

# === État du relais (par défaut OFF) ===
relay_state = True

# === Callback : quand le capteur reçoit un message (commande ON/OFF) ===
def on_message(client, userdata, msg):
    global relay_state
    payload = msg.payload.decode()
    try:
        data = json.loads(payload)
        command = data.get("command")
        if command == "ON":
            relay_state = True
            print("[RELAY] Power ON -> Reprise de l’envoi des données")
        elif command == "OFF":
            relay_state = False
            print("[RELAY] Power OFF -> Arrêt de l’envoi des données")
        else:
            print(f"[RELAY] Commande inconnue : {data}")
    except Exception as e:
        print(f"[ERROR] Impossible de décoder le message: {payload}, Erreur: {e}")

# === Configuration du client MQTT ===
client = mqtt.Client()
client.on_message = on_message

print("[INFO] Connexion au broker MQTT...")
client.connect(BROKER, PORT)
client.loop_start()
client.subscribe(TOPIC_RELAY)

print("[INFO] Sensor simulator started...")
print("[INFO] Relais par défaut = OFF (aucune donnée envoyée tant que ON n’est pas reçu)")

# === Boucle de simulation ===
try:
    while True:
        if relay_state:  # envoi uniquement si relais activé
            kwh = round(random.uniform(0.1, 0.3), 2)
            message = {
                "meter_number": METER_NUMBER,
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "kwh": kwh
            }
            client.publish(TOPIC_CONSUMPTION, json.dumps(message))
            print(f"[SENT] {message}")
        else:
            print("[INFO] Relais OFF - aucune donnée envoyée")

        time.sleep(2)  # toutes les 2 secondes

except KeyboardInterrupt:
    print("\n[INFO] Arrêt du simulateur...")
    client.loop_stop()
    client.disconnect()
