"""Prophet 기반 센서 데이터 이상 감지 + Gemini 기반 진단 메시지 생성.

묘목별 최근 센서 데이터 이력을 Prophet으로 학습해 다음 측정값을 예측하고,
실제 값과의 오차가 임계값을 넘으면 이상치로 판단한다.
이력이 부족하면(5개 미만) 단순 정상 범위 임계값 비교로 대체한다.
"""
import pandas as pd
from django.conf import settings
from langchain_google_genai import ChatGoogleGenerativeAI

from .models import SensorData

LLM_MODEL = 'gemini-2.5-flash'
GEMINI_TIMEOUT_SECONDS = 10

DIAGNOSIS_PROMPT_TEMPLATE = """당신은 무화과 재배 전문가입니다. 아래 센서 측정값과 정상 범위를 보고,
시니어 재배자가 이해하기 쉬운 한국어로 지금 상황과 어떤 조치를 취해야 하는지 2~3문장으로 안내해주세요.
전문 용어는 피하고 친근하고 다정한 말투를 사용하며, 딱 안내 문장만 출력해주세요.

측정값:
- 온도: {temperature}℃ (정상 범위: {temp_low}~{temp_high}℃)
- 습도: {humidity}% (정상 범위: {humidity_low}~{humidity_high}%)
- 조도: {light}lux (정상 범위: {light_low}~{light_high}lux)

이상이 감지된 항목: {anomaly_labels}"""

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
    # 최초 요청(특히 Render 슬립 복귀 직후 콜드 스타트)에서 프로세스 기동 시간을
    # 늘리지 않도록, 무거운 prophet 모듈은 실제로 예측이 필요한 시점에만 로드한다.
    # 파이썬이 모듈을 캐싱하므로 이후 호출부터는 재로드 없이 곧바로 재사용된다.
    from prophet import Prophet

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


def build_diagnosis_text(anomaly_fields, temperature, humidity, light):
    """gemini_diagnosis에 저장할 안내 텍스트를 생성한다.

    `GEMINI_API_KEY`가 설정돼 있으면 실제 Gemini API로 진단 문장을 생성하고,
    키가 비어있거나 호출이 실패하면(네트워크 오류, 타임아웃 등) 정적 템플릿으로 폴백한다.
    """
    if settings.GEMINI_API_KEY:
        try:
            return _generate_gemini_diagnosis(anomaly_fields, temperature, humidity, light)
        except Exception:
            pass
    return _build_static_diagnosis_text(anomaly_fields)


def _build_static_diagnosis_text(anomaly_fields):
    labels = ', '.join(FIELD_LABELS[field] for field in anomaly_fields)
    return f'이상 감지: {labels} 수치 이상'


def _generate_gemini_diagnosis(anomaly_fields, temperature, humidity, light):
    labels = ', '.join(FIELD_LABELS[field] for field in anomaly_fields)
    prompt = DIAGNOSIS_PROMPT_TEMPLATE.format(
        temperature=temperature,
        temp_low=FALLBACK_RANGES['temperature'][0],
        temp_high=FALLBACK_RANGES['temperature'][1],
        humidity=humidity,
        humidity_low=FALLBACK_RANGES['humidity'][0],
        humidity_high=FALLBACK_RANGES['humidity'][1],
        light=light,
        light_low=FALLBACK_RANGES['light'][0],
        light_high=FALLBACK_RANGES['light'][1],
        anomaly_labels=labels,
    )
    llm = ChatGoogleGenerativeAI(
        model=LLM_MODEL,
        google_api_key=settings.GEMINI_API_KEY,
        timeout=GEMINI_TIMEOUT_SECONDS,
    )
    response = llm.invoke(prompt)
    return response.content
