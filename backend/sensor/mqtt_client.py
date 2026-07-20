"""MQTT 구독 클라이언트.

`pigfig/sensor/{seedling_id}` topic을 구독해 수신한 센서 데이터를
SensorData로 저장한다. 저장 시 REST API(SensorDataCreateView)와 동일하게
Prophet 기반 이상 감지를 수행한다.

실행 방법:
    python sensor/mqtt_client.py
"""
import json
import os
import re

MQTT_BROKER_HOST = os.getenv('MQTT_BROKER_HOST', 'broker.hivemq.com')
MQTT_BROKER_PORT = int(os.getenv('MQTT_BROKER_PORT', '1883'))
TOPIC_FILTER = 'pigfig/sensor/+'
TOPIC_PATTERN = re.compile(r'^pigfig/sensor/(?P<seedling_id>\d+)$')


def _setup_django():
    """standalone 스크립트로 실행될 때 Django 앱 레지스트리를 초기화한다."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    import django
    django.setup()


def _on_connect(client, userdata, flags, reason_code, properties=None):
    print(f'[MQTT] 브로커({MQTT_BROKER_HOST}:{MQTT_BROKER_PORT}) 연결됨 (reason_code={reason_code})')
    client.subscribe(TOPIC_FILTER)
    print(f'[MQTT] 구독 시작: {TOPIC_FILTER}')


def _on_message(client, userdata, msg):
    from seedlings.models import Seedling

    from .anomaly import build_diagnosis_text, detect_anomaly
    from .models import SensorData

    match = TOPIC_PATTERN.match(msg.topic)
    if not match:
        print(f'[MQTT] 알 수 없는 topic 무시: {msg.topic}')
        return
    seedling_id = int(match.group('seedling_id'))

    try:
        payload = json.loads(msg.payload.decode('utf-8'))
        temperature = float(payload['temperature'])
        humidity = float(payload['humidity'])
        light = float(payload['light'])
    except (json.JSONDecodeError, KeyError, ValueError, TypeError) as exc:
        print(f'[MQTT] 잘못된 payload 무시: {msg.payload!r} ({exc})')
        return

    try:
        seedling = Seedling.objects.get(pk=seedling_id)
    except Seedling.DoesNotExist:
        print(f'[MQTT] 존재하지 않는 seedling_id: {seedling_id}')
        return

    is_anomaly, anomaly_fields = detect_anomaly(seedling, temperature, humidity, light)
    gemini_diagnosis = build_diagnosis_text(anomaly_fields) if is_anomaly else None

    SensorData.objects.create(
        seedling=seedling,
        temperature=temperature,
        humidity=humidity,
        light=light,
        is_anomaly=is_anomaly,
        gemini_diagnosis=gemini_diagnosis,
    )
    print(
        f'[MQTT] 저장됨: seedling={seedling_id} '
        f'temp={temperature} hum={humidity} light={light} anomaly={is_anomaly}'
    )


def build_client():
    import paho.mqtt.client as mqtt

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = _on_connect
    client.on_message = _on_message
    return client


def run():
    """MQTT 브로커에 연결해 센서 데이터 수신을 시작한다 (blocking)."""
    client = build_client()
    client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT)
    client.loop_forever()


if __name__ == '__main__':
    _setup_django()
    run()
