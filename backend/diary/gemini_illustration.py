"""Gemini 이미지 생성 모델 기반 일지 사진 -> 동화풍 일러스트 변환.

재배자가 업로드한 실사진(Diary.photo)을 감성적인 일러스트로 변환해 입양자
타임라인에 보여준다. `GEMINI_API_KEY`가 비어있으면(로컬 기본값) 호출 자체를
생략하고, 키가 있어도 호출이 실패하면(쿼터 초과, 네트워크 오류 등) None을
반환한다 — 두 경우 모두 원본 사진만 저장되고 일지 작성 자체는 정상 처리된다
(sensor/anomaly.py, vision/yolo_inference.py와 동일한 게이트 체크 -> try/except
-> 폴백 패턴).
"""
import mimetypes

from django.conf import settings

LLM_MODEL = 'gemini-2.5-flash-image'
GEMINI_TIMEOUT_SECONDS = 30

ILLUSTRATION_PROMPT = (
    '이 식물 사진을 아동 그림책(picture book illustration) 스타일의 귀여운(cute) 일러스트로 '
    '다시 그려주세요. photorealistic, realistic photo처럼 보이면 절대 안 됩니다 — 사진 같은 '
    '질감이나 정교한 명암은 배제하고, flat color(플랫 컬러), 부드러운 선, 파스텔톤 색감, '
    '단순화된(simplified) 형태로 그려주세요. 손그림 느낌의 따뜻하고 동화 같은 그림체여야 합니다. '
    '잎의 개수와 크기, 줄기 굵기, 성장 정도 등 식물의 실제 상태는 최대한 그대로 유지해주세요.'
)


def convert_to_illustration(photo_path):
    """묘목 사진을 일러스트로 변환해 이미지 bytes를 반환한다.

    Args:
        photo_path: 원본 사진 파일 경로

    Returns:
        bytes | None: 변환된 이미지의 raw bytes. 키 미설정이거나 변환에 실패하면 None.
    """
    if not settings.GEMINI_API_KEY:
        return None
    try:
        return _generate_illustration(photo_path)
    except Exception:
        return None


def _generate_illustration(photo_path):
    from google import genai
    from google.genai import types

    with open(photo_path, 'rb') as f:
        photo_bytes = f.read()
    mime_type = mimetypes.guess_type(photo_path)[0] or 'image/jpeg'

    client = genai.Client(
        api_key=settings.GEMINI_API_KEY,
        http_options=types.HttpOptions(timeout=GEMINI_TIMEOUT_SECONDS * 1000),
    )
    response = client.models.generate_content(
        model=LLM_MODEL,
        contents=[
            ILLUSTRATION_PROMPT,
            types.Part.from_bytes(data=photo_bytes, mime_type=mime_type),
        ],
    )

    for part in response.candidates[0].content.parts:
        if part.inline_data is not None:
            return part.inline_data.data
    return None
