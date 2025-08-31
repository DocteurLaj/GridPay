# test_mqtt.py
import paho.mqtt.client as mqtt
import json
import time
from datetime import datetime

BROKER = "broker.hivemq.com"
PORT = 1883
METER_NUMBER = "CNT-452-568-985"
TOPIC_CONSUMPTION = f"electricity/{METER_NUMBER}/consumption"

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connecté au broker MQTT")
    else:
        print(f"Erreur de connexion: {rc}")

client = mqtt.Client()
client.on_connect = on_connect

client.connect(BROKER, PORT)
client.loop_start()

print("Envoi de données de test...")

# Envoyer des données de test
for i in range(5):
    consumption_data = {
        "meter_number": METER_NUMBER,
        "kwh": 0.25 + (i * 0.05),
        "timestamp": datetime.now().isoformat()
    }
    
    client.publish(TOPIC_CONSUMPTION, json.dumps(consumption_data))
    print(f"Donnée envoyée: {consumption_data}")
    time.sleep(2)

client.loop_stop()
client.disconnect()