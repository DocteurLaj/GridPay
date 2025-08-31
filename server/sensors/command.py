# controller.py
import json
import paho.mqtt.client as mqtt

# === Configuration Broker MQTT ===
BROKER = "broker.hivemq.com"   # même broker que le simulateur
PORT = 1883
METER_NUMBER = "CNT-001"

# === Topics ===
TOPIC_CONSUMPTION = f"electricity/{METER_NUMBER}/consumption"
TOPIC_RELAY = f"electricity/{METER_NUMBER}/relay"

# === Callback quand on reçoit des données de consommation ===
def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    try:
        data = json.loads(payload)
        print(f"[CONSUMPTION] {data}")
    except Exception as e:
        print(f"[ERROR] Erreur décodage: {payload}, {e}")

# === Config MQTT ===
client = mqtt.Client()
client.on_message = on_message

print("[INFO] Connexion au broker MQTT...")
client.connect(BROKER, PORT)
client.loop_start()

# Souscrire aux messages de consommation envoyés par le simulateur
client.subscribe(TOPIC_CONSUMPTION)
print("[INFO] Contrôleur démarré. Tape 'ON' ou 'OFF' pour contrôler le relais. 'exit' pour quitter.\n")

# === Boucle de commande ===
try:
    while True:
        cmd = input("Commande > ").strip().upper()
        if cmd in ["ON", "OFF"]:
            message = {"command": cmd}
            client.publish(TOPIC_RELAY, json.dumps(message))
            print(f"[SENT] {message}")
        elif cmd == "EXIT":
            break
        else:
            print("[WARNING] Commande invalide. Utilise 'ON', 'OFF' ou 'exit'.")

except KeyboardInterrupt:
    print("\n[INFO] Arrêt du contrôleur...")

finally:
    client.loop_stop()
    client.disconnect()
