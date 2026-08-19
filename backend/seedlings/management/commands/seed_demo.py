"""포스터 캡처/데모용 시드 데이터 생성 커맨드.

python manage.py seed_demo

## 계정 6개
- adopter@demo.com  (입양자, 닉네임 "김입양")  — 묘목 #1(재배중) 담당
- adopter2@demo.com (입양자, 닉네임 "이동본")  — 묘목 #2(재배중) 담당
- grower@demo.com   (재배자, 닉네임 "박재배")  — 묘목 5그루 전부 담당
- dummy1@demo.com   (입양자, 닉네임 "최나윤")  — 묘목 #3(재배중) 담당
- dummy2@demo.com   (입양자, 닉네임 "정시원")  — 묘목 #4(완료·기부 확정) 담당
- dummy3@demo.com   (입양자, 닉네임 "한겨울")  — 묘목 #5(완료·수령 확정) 담당
(비밀번호는 전부 demo1234)

## 묘목 5개 (전부 grower@demo.com 담당)
재배중 3그루(#1~#3)는 각각 성장 단계가 다른 시점(rooting만 / rooting→leafing /
rooting→leafing→branching)까지 진행된 상태로 만들어 재배자 홈(선반 뷰)의 성장 단계
배지가 묘목마다 다르게 보이도록 한다. 완료 2그루(#4~#5)는 pickup_or_donate까지 이미
선택된 상태(#4=기부/도시농업 공동체, #5=수령)로 만들어 마이페이지의 기부 인증서 등
완료 후 화면도 바로 확인할 수 있게 한다.

## 일지
재배중 묘목(#1~#3)은 성장 단계 진행에 맞춰 1~3건, 완료 묘목(#4~#5)은 완성 직전
mature 단계 1건씩 만든다. 날짜는 전부 `timezone.now()` 기준 최근 2주 이내로 역산한
상대 날짜라, 커맨드를 실행하는 시점에 따라 실제 달력 날짜가 달라진다(고정 달력
날짜를 쓰던 예전 버전과 다른 점). 모든 일지에 `backend/media/diary/photos/`에 이미
있는 실사진(SOURCE_PHOTO_NAMES)을 순환 배정해 photo 필드를 실제로 채운다 — 원래
계획은 `backend/media/seed_demo_photos/`라는 전용 폴더에서 사진을 가져오는 것이었지만
이 커맨드를 작성하는 시점에 그 폴더가 로컬에 없었고(2026-08-19 확인), 이미
diary/photos/에 있는 무화과 실사진들로 대체하기로 했다 — 나중에 전용 사진을 넣고
싶다면 SOURCE_PHOTO_NAMES와 `_load_source_photos()`의 경로만 바꾸면 된다.

## 센서 데이터
5개 묘목에 걸쳐 3~4건씩(총 17건) 만든다. 묘목당 3~4건은 Prophet 학습 최소치
(`sensor.anomaly.MIN_DATA_FOR_PROPHET` = 5)에 못 미쳐 전부 `_detect_by_threshold()`
(단순 정상 범위 비교) 경로를 타므로, 값 하나만 `FALLBACK_RANGES` 밖으로 잡으면
순서와 무관하게 그 값이 곧바로 이상치로 판정된다 — Prophet 예측까지 확인하려면
`grower_sensor_screen.dart`에서 실제로 6번째 값을 추가로 저장해봐야 한다. 이상치는
총 3건을 묘목 #1에 2건(습도 1건 + 조도 1건), 묘목 #3에 1건(온도)으로 몰아서 넣었다
— 전부 다른 묘목에 1건씩 고르게 나누면 `grower_anomaly_summary_screen.dart`의 게이지
막대가 전부 동일한 높이(1/1)로만 보여 비교가 안 되므로, 일부러 편차를 줬다.
`SensorDataCreateView.perform_create()`와 동일하게 `detect_anomaly()`/
`build_diagnosis_text()`를 실제로 호출해서 저장한다(직접 `is_anomaly=True`를
박아넣지 않는다) — `GEMINI_API_KEY`가 설정돼 있으면 `gemini_diagnosis`도 실제
Gemini 응답으로 채워진다.

## 멱등성
계정은 이메일, 묘목은 (입양자, 재배자, 상태) 조합, 일지/센서 데이터는 묘목별로
하나라도 있으면 그 묘목 전체를 스킵한다 — 이미 존재하는 것은 건드리지 않고
건너뛴다. 재실행해도 중복 생성되지 않는다.

이전 버전(계정 3개/묘목 3개)은 이 구조로 완전히 대체됐다.
"""
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.core.files import File
from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from diary.models import Diary
from sensor.anomaly import build_diagnosis_text, detect_anomaly
from sensor.models import SensorData

from seedlings.models import Seedling

DEMO_PASSWORD = 'demo1234'

# (내부 키, 이메일, role, 닉네임)
ACCOUNT_SPECS = [
    ('adopter', 'adopter@demo.com', User.Role.ADOPTER, '김입양'),
    ('adopter2', 'adopter2@demo.com', User.Role.ADOPTER, '이동본'),
    ('grower', 'grower@demo.com', User.Role.GROWER, '박재배'),
    ('dummy1', 'dummy1@demo.com', User.Role.ADOPTER, '최나윤'),
    ('dummy2', 'dummy2@demo.com', User.Role.ADOPTER, '정시원'),
    ('dummy3', 'dummy3@demo.com', User.Role.ADOPTER, '한겨울'),
]

# (내부 키, 입양자 키, 상태, pickup_or_donate, donate_type, 표시 라벨)
SEEDLING_SPECS = [
    ('seedling1', 'adopter', Seedling.Status.GROWING, None, None,
     '#1 (김입양, 재배중)'),
    ('seedling2', 'adopter2', Seedling.Status.GROWING, None, None,
     '#2 (이동본, 재배중)'),
    ('seedling3', 'dummy1', Seedling.Status.GROWING, None, None,
     '#3 (최나윤, 재배중)'),
    ('seedling4', 'dummy2', Seedling.Status.COMPLETED,
     Seedling.PickupOrDonate.DONATE, Seedling.DonateType.URBAN_FARMING_COMMUNITY,
     '#4 (정시원, 완료·기부)'),
    ('seedling5', 'dummy3', Seedling.Status.COMPLETED,
     Seedling.PickupOrDonate.PICKUP, None,
     '#5 (한겨울, 완료·수령)'),
]

# backend/media/diary/photos/에 이미 있는 실사진 중 순환 배정할 파일들.
SOURCE_PHOTO_NAMES = [
    'fig_real.jpg',
    'leaf.jpg',
    'scaled_KakaoTalk_20260721_154630614_01.jpg',
    'scaled_무화과사진.jpg',
]


class Command(BaseCommand):
    help = '포스터 캡처/데모용 계정·묘목·일지·센서 데이터를 생성한다 (멱등).'

    def handle(self, *args, **options):
        self._source_photos = self._load_source_photos()
        self._photo_index = 0

        self.stdout.write('계정 생성')
        accounts = self._seed_accounts()

        self.stdout.write('묘목 생성')
        seedlings = self._seed_seedlings(accounts)

        self.stdout.write('일지 생성')
        self._seed_all_diaries(seedlings, accounts['grower'])

        self.stdout.write('센서 데이터 생성')
        self._seed_all_sensor_data(seedlings)

        self.stdout.write(self.style.SUCCESS('시드 데이터 준비 완료'))
        self._print_summary(accounts, seedlings)

    # ------------------------------------------------------------------
    # 계정
    # ------------------------------------------------------------------

    def _seed_accounts(self):
        return {
            key: self._get_or_create_user(email, role, nickname)
            for key, email, role, nickname in ACCOUNT_SPECS
        }

    def _get_or_create_user(self, email, role, nickname):
        user = User.objects.filter(email=email).first()
        if user:
            self.stdout.write(f'  스킵 (이미 존재): {email}')
            return user
        user = User.objects.create_user(
            email=email, password=DEMO_PASSWORD, role=role, nickname=nickname,
        )
        self.stdout.write(self.style.SUCCESS(f'  생성: {email} ({role}, {nickname})'))
        return user

    # ------------------------------------------------------------------
    # 묘목
    # ------------------------------------------------------------------

    def _seed_seedlings(self, accounts):
        grower = accounts['grower']
        seedlings = {}
        for key, adopter_key, status, pickup_or_donate, donate_type, label in SEEDLING_SPECS:
            seedlings[key] = self._get_or_create_seedling(
                accounts[adopter_key],
                grower,
                status,
                label,
                pickup_or_donate=pickup_or_donate,
                donate_type=donate_type,
            )
        return seedlings

    def _get_or_create_seedling(
        self, adopter, grower, status, label, *, pickup_or_donate, donate_type,
    ):
        seedling = Seedling.objects.filter(
            adopter=adopter, grower=grower, status=status,
        ).first()
        if seedling:
            self.stdout.write(f'  스킵 (이미 존재): 묘목 {label} -> #{seedling.pk}')
            return seedling

        seedling = Seedling.objects.create(adopter=adopter, grower=grower, status=status)
        if status == Seedling.Status.COMPLETED:
            Seedling.objects.filter(pk=seedling.pk).update(
                completed_at=timezone.now() - timedelta(days=1),
                pickup_or_donate=pickup_or_donate,
                donate_type=donate_type,
            )
            seedling.refresh_from_db()
        self.stdout.write(self.style.SUCCESS(f'  생성: 묘목 {label} -> #{seedling.pk}'))
        return seedling

    # ------------------------------------------------------------------
    # 일지 + 사진
    # ------------------------------------------------------------------

    def _load_source_photos(self):
        photos_dir = Path(settings.MEDIA_ROOT) / 'diary' / 'photos'
        candidates = [photos_dir / name for name in SOURCE_PHOTO_NAMES]
        existing = [path for path in candidates if path.exists()]
        missing = [path.name for path in candidates if not path.exists()]
        if missing:
            self.stdout.write(self.style.WARNING(
                f'  사진 파일을 찾을 수 없어 건너뜁니다: {", ".join(missing)}',
            ))
        if not existing:
            self.stdout.write(self.style.WARNING(
                '  사용 가능한 원본 사진이 없어 일지에 사진을 첨부하지 않습니다.',
            ))
        return existing

    def _next_photo_path(self):
        if not self._source_photos:
            return None
        path = self._source_photos[self._photo_index % len(self._source_photos)]
        self._photo_index += 1
        return path

    def _attach_photo(self, diary, seedling, stage):
        path = self._next_photo_path()
        if path is None:
            return
        filename = f'seed_{seedling.pk}_{stage}{path.suffix}'
        with path.open('rb') as fh:
            diary.photo.save(filename, File(fh), save=True)

    def _seed_all_diaries(self, seedlings, grower):
        # (경과일, growth_stage, content) — 경과일이 클수록 과거, 작을수록 최근.
        self._seed_diaries_for_seedling(seedlings['seedling1'], grower, [
            (5, Diary.GrowthStage.ROOTING,
             '오늘 첫 새싹이 올라왔어요! 흙 사이로 여린 순이 빼꼼 고개를 내밀었어요 🌱'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling2'], grower, [
            (10, Diary.GrowthStage.ROOTING,
             '뿌리가 자리를 잡았는지 흙 위로 여린 싹이 올라왔어요. 매일 조금씩 물을 주고 있습니다.'),
            (4, Diary.GrowthStage.LEAFING,
             '잎이 하나둘 펼쳐지기 시작했어요! 초록빛이 눈에 띄게 짙어졌습니다.'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling3'], grower, [
            (13, Diary.GrowthStage.ROOTING,
             '입양된 지 얼마 안 됐는데 벌써 뿌리를 내렸는지 새순이 올라왔어요.'),
            (8, Diary.GrowthStage.LEAFING,
             '잎이 제법 넓어졌어요. 햇볕을 잘 받도록 자리를 조금 옮겨줬습니다.'),
            (2, Diary.GrowthStage.BRANCHING,
             '가지가 두 갈래로 뻗어나갔어요! 하루가 다르게 무성해지고 있습니다.'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling4'], grower, [
            (3, Diary.GrowthStage.MATURE,
             '잎도 가지도 무성하게 자라 이제 완성을 앞두고 있어요. 곧 기부처로 보낼 준비를 할게요!'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling5'], grower, [
            (3, Diary.GrowthStage.MATURE,
             '튼튼하게 다 자랐어요! 입양자님께서 직접 수령하러 오실 날이 머지않았습니다.'),
        ])

    def _seed_diaries_for_seedling(self, seedling, grower, entries):
        if Diary.objects.filter(seedling=seedling).exists():
            self.stdout.write(f'  스킵 (이미 존재): 묘목 #{seedling.pk} 일지')
            return

        now = timezone.now()
        for days_ago, stage, content in entries:
            diary = Diary.objects.create(
                seedling=seedling, grower=grower, content=content, growth_stage=stage,
            )
            self._attach_photo(diary, seedling, stage)
            created_at = timezone.localtime(now - timedelta(days=days_ago)).replace(
                hour=9, minute=0, second=0, microsecond=0,
            )
            Diary.objects.filter(pk=diary.pk).update(created_at=created_at)
        self.stdout.write(self.style.SUCCESS(
            f'  생성: 묘목 #{seedling.pk} 일지 {len(entries)}건',
        ))

    # ------------------------------------------------------------------
    # 센서 데이터
    # ------------------------------------------------------------------

    def _seed_all_sensor_data(self, seedlings):
        # (경과일, 온도, 습도, 조도) — FALLBACK_RANGES: 온도 10~35 / 습도 30~90 /
        # 조도 100~1000. 묘목당 3~4건이라 항상 Prophet 최소치(5건) 미만이라
        # detect_anomaly()는 매번 단순 임계값 비교로만 판정한다.
        self._seed_sensor_data_for_seedling(seedlings['seedling1'], [
            (4, 22.0, 63.0, 520.0),
            (3, 23.0, 64.0, 560.0),
            (1, 21.0, 95.0, 540.0),    # 이상: 습도
            (0, 22.0, 65.0, 1400.0),   # 이상: 조도
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling2'], [
            (5, 22.0, 62.0, 500.0),
            (3, 23.0, 64.0, 510.0),
            (1, 22.0, 63.0, 495.0),
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling3'], [
            (6, 23.0, 60.0, 500.0),
            (4, 24.0, 62.0, 480.0),
            (2, 7.0, 61.0, 510.0),     # 이상: 온도
            (0, 23.0, 63.0, 495.0),
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling4'], [
            (6, 22.0, 61.0, 520.0),
            (4, 23.0, 63.0, 500.0),
            (2, 22.0, 62.0, 510.0),
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling5'], [
            (6, 21.0, 60.0, 490.0),
            (4, 22.0, 62.0, 505.0),
            (2, 23.0, 61.0, 500.0),
        ])

    def _seed_sensor_data_for_seedling(self, seedling, readings):
        if SensorData.objects.filter(seedling=seedling).exists():
            self.stdout.write(f'  스킵 (이미 존재): 묘목 #{seedling.pk} 센서 데이터')
            return

        now = timezone.now()
        for days_ago, temperature, humidity, light in readings:
            # SensorDataCreateView.perform_create()와 동일한 순서로 판단→저장한다.
            is_anomaly, anomaly_fields = detect_anomaly(seedling, temperature, humidity, light)
            gemini_diagnosis = (
                build_diagnosis_text(anomaly_fields, temperature, humidity, light)
                if is_anomaly else None
            )
            record = SensorData.objects.create(
                seedling=seedling,
                temperature=temperature,
                humidity=humidity,
                light=light,
                is_anomaly=is_anomaly,
                gemini_diagnosis=gemini_diagnosis,
            )
            recorded_at = now - timedelta(days=days_ago)
            SensorData.objects.filter(pk=record.pk).update(recorded_at=recorded_at)

        anomaly_count = SensorData.objects.filter(seedling=seedling, is_anomaly=True).count()
        self.stdout.write(self.style.SUCCESS(
            f'  생성: 묘목 #{seedling.pk} 센서 데이터 {len(readings)}건 (이상 {anomaly_count}건)',
        ))

    # ------------------------------------------------------------------
    # 요약 출력
    # ------------------------------------------------------------------

    def _print_summary(self, accounts, seedlings):
        self.stdout.write('')
        self.stdout.write('=== 데모 계정 ===')
        self.stdout.write(
            f"  입양자   : {accounts['adopter'].email} / {DEMO_PASSWORD}  "
            f"(닉네임 김입양, 묘목 #{seedlings['seedling1'].pk} 담당)",
        )
        self.stdout.write(
            f"  입양자2  : {accounts['adopter2'].email} / {DEMO_PASSWORD}  "
            f"(닉네임 이동본, 묘목 #{seedlings['seedling2'].pk} 담당)",
        )
        self.stdout.write(
            f"  재배자   : {accounts['grower'].email} / {DEMO_PASSWORD}  "
            f"(닉네임 박재배, 묘목 5그루 담당)",
        )
        self.stdout.write(
            f"  더미1    : {accounts['dummy1'].email} / {DEMO_PASSWORD}  "
            f"(닉네임 최나윤, 묘목 #{seedlings['seedling3'].pk} 담당)",
        )
        self.stdout.write(
            f"  더미2    : {accounts['dummy2'].email} / {DEMO_PASSWORD}  "
            f"(닉네임 정시원, 묘목 #{seedlings['seedling4'].pk} 담당 — 완료·기부 확정)",
        )
        self.stdout.write(
            f"  더미3    : {accounts['dummy3'].email} / {DEMO_PASSWORD}  "
            f"(닉네임 한겨울, 묘목 #{seedlings['seedling5'].pk} 담당 — 완료·수령 확정)",
        )
