"""YOLOv8 기반 묘목 이미지 분석.

아직 실제 무화과 학습 데이터셋이 없어 현재는 mock 추론으로 대체한다.
DRB에서 촬영한 사진으로 커스텀 학습을 마치면 `_MODEL_PATH`를 학습된 가중치
경로로 바꾸고 `_mock_inference()` 호출부를 실제 추론 결과 파싱 코드로 교체하면
된다 (`analyze_image()`의 인자/반환 형식은 그대로 유지).
"""
import random

_MODEL_PATH = 'yolov8n.pt'
_model = None

RESULT_TAGS = ('정상', '수분부족', '과습', '조명이상')
SHELF_COUNT = 3
POSITION_COUNT = 5
CONFIDENCE_RANGE = (0.7, 0.99)


def _get_model():
    """YOLO 모델을 lazy하게 로드해 캐싱한다 (실제 추론 도입 시 사용)."""
    global _model
    if _model is None:
        from ultralytics import YOLO

        _model = YOLO(_MODEL_PATH)
    return _model


def analyze_image(image_path):
    """묘목 이미지를 분석해 상태 태그·신뢰도·위치 정보를 반환한다.

    Args:
        image_path: 분석할 이미지 파일 경로

    Returns:
        dict: {'result_tag': str, 'confidence': float, 'location_info': str}
    """
    return _mock_inference(image_path)


def _mock_inference(image_path):
    return {
        'result_tag': random.choice(RESULT_TAGS),
        'confidence': round(random.uniform(*CONFIDENCE_RANGE), 2),
        'location_info': (
            f'선반{random.randint(1, SHELF_COUNT)}-{random.randint(1, POSITION_COUNT)}번'
        ),
    }
