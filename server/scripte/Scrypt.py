# sensor_simulator.py
import time
import json
import random
import paho.mqtt.client as mqtt

BROKER = "localhost"  # ou l'IP de ton serveur MQTT
PORT = 1883
METER_NUMBER = "CNT-001"

# MQTT topics
TOPIC_CONSUMPTION = f"electricity/{METER_NUMBER}/consumption"
TOPIC_RELAY = f"electricity/{METER_NUMBER}/relay"

# Callback quand le capteur reçoit un message (commande ON/OFF)
def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    data = json.loads(payload)
    command = data.get("command")
    if command == "ON":
        print("[RELAY] Power ON")
    elif command == "OFF":
        print("[RELAY] Power OFF")

client = mqtt.Client()
client.on_message = on_message
client.connect(BROKER, PORT)
client.loop_start()
client.subscribe(TOPIC_RELAY)

print("Sensor simulator started...")

try:
    while True:
        # simuler une consommation aléatoire entre 0.1 et 0.3 kWh
        kwh = round(random.uniform(0.1, 0.3), 2)
        message = {
            "meter_number": METER_NUMBER,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "kwh": kwh
        }
        client.publish(TOPIC_CONSUMPTION, json.dumps(message))
        print(f"[SENT] {message}")
        time.sleep(60)  # envoie toutes les minutes
except KeyboardInterrupt:
    client.loop_stop()
    client.disconnect()
