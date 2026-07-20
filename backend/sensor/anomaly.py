"""Prophet 기반 센서 데이터 이상 감지.

묘목별 최근 센서 데이터 이력을 Prophet으로 학습해 다음 측정값을 예측하고,
실제 값과의 오차가 임계값을 넘으면 이상치로 판단한다.
이력이 부족하면(5개 미만) 단순 정상 범위 임계값 비교로 대체한다.
"""
import pandas as pd
from prophet import Prophet

from .models import SensorData

FIELDS = ('temperature', 'humidity', 'light')

FIELD_LABELS = {
    'temperature': '온도',
    'humidity': '습도',
    'light': '조도',
}

# Prophet 예측값 대비 실제값 오차 임계값
PROPHET_THRESHOLDS = {
    'temperature': 3,
    'humidity': 15,
    'light': 200,
}

# 이력 부족 시 fallback으로 사용하는 정상 범위
FALLBACK_RANGES = {
    'temperature': (10, 35),
    'humidity': (30, 90),
    'light': (100, 1000),
}

MIN_DATA_FOR_PROPHET = 5
RECENT_LIMIT = 20


def detect_anomaly(seedling, temperature, humidity, light):
    """새로 측정된 값의 이상 여부를 판단한다.

    Returns:
        (is_anomaly, anomaly_fields): 이상 여부와 이상이 감지된 필드명 리스트
    """
    history = list(
        SensorData.objects.filter(seedling=seedling).order_by('-recorded_at')[:RECENT_LIMIT]
    )
    history.reverse()  # 오래된 순으로 정렬 (Prophet 입력 형식)

    current_values = {'temperature': temperature, 'humidity': humidity, 'light': light}

    if len(history) < MIN_DATA_FOR_PROPHET:
        return _detect_by_threshold(current_values)
    return _detect_by_prophet(history, current_values)


def _detect_by_threshold(current_values):
    anomaly_fields = [
        field
        for field in FIELDS
        if not (FALLBACK_RANGES[field][0] <= current_values[field] <= FALLBACK_RANGES[field][1])
    ]
    return bool(anomaly_fields), anomaly_fields


def _detect_by_prophet(history, current_values):
    anomaly_fields = []
    for field in FIELDS:
        predicted = _forecast_next_value(history, field)
        if predicted is None:
            # Prophet 예측 실패 시 해당 필드는 판단하지 않고 넘어간다
            continue
        if abs(current_values[field] - predicted) > PROPHET_THRESHOLDS[field]:
            anomaly_fields.append(field)
    return bool(anomaly_fields), anomaly_fields


def _forecast_next_value(history, field):
    df = pd.DataFrame({
        'ds': [record.recorded_at.replace(tzinfo=None) for record in history],
        'y': [getattr(record, field) for record in history],
    })
    try:
        model = Prophet()
        model.fit(df)
        future = model.make_future_dataframe(periods=1, freq='min')
        forecast = model.predict(future)
        return float(forecast['yhat'].iloc[-1])
    except Exception:
        return None


def build_diagnosis_text(anomaly_fields):
    """gemini_diagnosis에 저장할 안내 텍스트를 생성한다.

    Gemini API 연동은 chatbot 앱 완성 후 고도화 예정이라 지금은 텍스트로 대체한다.
    """
    labels = ', '.join(FIELD_LABELS[field] for field in anomaly_fields)
    return f'이상 감지: {labels} 수치 이상'
