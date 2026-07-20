"""가상 센서 시뮬레이터.

Django/DB에 의존하지 않는 순수 MQTT 퍼블리셔로, 10초 간격으로 임의의
온도(18~28도)/습도(50~80%)/조도(200~800lux) 값을 `pigfig/sensor/{seedling_id}`
topic에 발행한다.

실행 방법:
    python sensor/mock_sensor.py <seedling_id> [--interval 10]
"""
import argparse
import json
import os
import random
import time

import paho.mqtt.client as mqtt

MQTT_BROKER_HOST = os.getenv('MQTT_BROKER_HOST', 'broker.hivemq.com')
MQTT_BROKER_PORT = int(os.getenv('MQTT_BROKER_PORT', '1883'))
PUBLISH_INTERVAL_SECONDS = 10


def generate_reading():
    return {
        'temperature': round(random.uniform(18, 28), 1),
        'humidity': round(random.uniform(50, 80), 1),
        'light': round(random.uniform(200, 800), 1),
    }


def run(seedling_id, interval=PUBLISH_INTERVAL_SECONDS):
    topic = f'pigfig/sensor/{seedling_id}'
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.connect(MQTT_BROKER_HOST, MQTT_BROKER_PORT)
    client.loop_start()

    print(f'[MockSensor] {topic} 로 {interval}초 간격 발행 시작 (Ctrl+C로 종료)')
    try:
        while True:
            reading = generate_reading()
            client.publish(topic, json.dumps(reading))
            print(f'[MockSensor] 발행: {reading}')
            time.sleep(interval)
    except KeyboardInterrupt:
        print('[MockSensor] 종료')
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Pig.Fig. 가상 센서 시뮬레이터')
    parser.add_argument('seedling_id', type=int, help='데이터를 발행할 묘목 ID')
    parser.add_argument('--interval', type=float, default=PUBLISH_INTERVAL_SECONDS)
    args = parser.parse_args()
    run(args.seedling_id, args.interval)
