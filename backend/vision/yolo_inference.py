"""YOLOv8 기반 묘목 이미지 분석.

`_MODEL_PATH`(backend/vision/weights/best.pt)가 있으면 실제 YOLOv8-cls(분류) 모델로 추론하고,
없으면(다른 팀원 로컬/CI — 이 파일은 .gitignore 대상이라 커밋되지 않음) mock 추론으로 폴백한다.
"""
import random
from pathlib import Path

_MODEL_PATH = Path(__file__).resolve().parent / 'weights' / 'best.pt'
_model = None

RESULT_TAGS = ('정상', '수분부족', '과습', '조명이상')  # mock 폴백 전용
SHELF_COUNT = 3
POSITION_COUNT = 5
CONFIDENCE_RANGE = (0.7, 0.99)

# 실제 모델(healthy/infected 이진 분류)의 클래스명 -> 화면에 보여줄 한국어 태그
REAL_CLASS_TO_TAG = {
    'healthy': '정상',
    'infected': '이상감지',
}


def _get_model():
    """YOLO 모델을 lazy하게 로드해 프로세스당 한 번만 캐싱한다."""
    global _model
    if _model is None:
        from ultralytics import YOLO

        _model = YOLO(str(_MODEL_PATH))
    return _model


def analyze_image(image_path):
    """묘목 이미지를 분석해 상태 태그·신뢰도·위치 정보를 반환한다.

    `_MODEL_PATH`가 있으면 실제 추론을 쓰고, 없거나 추론 중 예외가 나면 mock 추론으로
    조용히 폴백한다(sensor/anomaly.py의 Gemini 폴백과 동일한 패턴).

    Args:
        image_path: 분석할 이미지 파일 경로

    Returns:
        dict: {'result_tag': str, 'confidence': float, 'location_info': str | None}
    """
    if _MODEL_PATH.exists():
        try:
            return _run_inference(image_path)
        except Exception:
            pass
    return _mock_inference(image_path)


def _run_inference(image_path):
    model = _get_model()
    result = model(image_path, verbose=False)[0]
    class_name = result.names[result.probs.top1]
    confidence = float(result.probs.top1conf)
    return {
        'result_tag': REAL_CLASS_TO_TAG.get(class_name, class_name),
        'confidence': confidence,
        # classification 모델이라 잎의 위치 좌표는 알 수 없다.
        # detection 모델 도입 시 실제 위치 정보로 교체 예정.
        'location_info': None,
    }


def _mock_inference(image_path):
    return {
        'result_tag': random.choice(RESULT_TAGS),
        'confidence': round(random.uniform(*CONFIDENCE_RANGE), 2),
        'location_info': (
            f'선반{random.randint(1, SHELF_COUNT)}-{random.randint(1, POSITION_COUNT)}번'
        ),
    }
