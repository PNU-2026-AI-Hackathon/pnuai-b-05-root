"""포스터 캡처/데모용 시드 데이터 생성 커맨드.

python manage.py seed_demo

## 계정 6개
- grower@demo.com   (재배자, 닉네임 "박재배")  — 묘목 5그루 전부 담당 (유지 대상)
- adopter1@demo.com (입양자, 닉네임 "김하늘")  — 묘목 #1 발근 중 · 재배중
- adopter2@demo.com (입양자, 닉네임 "이서준")  — 묘목 #2 잎 성장 중 · 재배중
- adopter3@demo.com (입양자, 닉네임 "박지우")  — 묘목 #3 가지 발달 · 재배중
- adopter4@demo.com (입양자, 닉네임 "최민서")  — 묘목 #4 완성 · 완료·기부(도시농업 공동체)
- adopter5@demo.com (입양자, 닉네임 "정예린")  — 묘목 #5 가지 발달 · 재배중
(비밀번호는 전부 demo1234)

## 실행 시 초기화 (예전 버전과 가장 크게 달라진 점)
매 실행마다 handle() 맨 앞에서 구버전 데모 입양자(adopter@demo.com/adopter2@demo.com/
dummy1~3@demo.com)와 이 스크립트가 만드는 신버전 입양자(adopter1~5@demo.com)를
`User.objects.filter(email__in=...).delete()`로 먼저 삭제한다 — `Seedling.adopter` 등
관련 FK가 전부 `on_delete=CASCADE`라, 그 입양자의 묘목/일지/센서 데이터/비전 분석이
함께 지워진다(프로젝트에 post_delete 시그널은 없다). 완료 알림(SeedlingCompleteView)은
API 뷰 안에만 있고 이 시딩 경로(ORM create/update)는 거치지 않으므로, 삭제·재생성 어느
쪽에서도 이메일/FCM이 발송되지 않는다. 재배자(grower@demo.com)는 삭제 목록에 없어 그대로
유지된다(get_or_create로 멱등). 즉 **입양자 데이터는 "매번 삭제 후 재생성", 재배자만 멱등**이다.

## 성장 단계(growth_stage)
`Seedling` 모델에는 growth_stage 필드가 없다 — 앱이 화면에 보여주는 성장 단계는
"그 묘목의 가장 최근 일지(created_at 기준)의 `Diary.growth_stage`"에서 파생된다
(입양자 홈 `_fetchGrowthStageState`, 재배자 선반 `_latestDiary` 둘 다 동일). 그래서
각 묘목의 목표 단계는 일지 리스트의 마지막(가장 최근) 항목에 그 단계를 넣어 만든다.
#1=rooting / #2=leafing / #3=branching / #4=mature / #5=branching.

## 일지
묘목당 3~4건. 발근→잎→가지→완성 순서로 진행하되 마지막 항목이 위 목표 단계가 되도록
구성한다. 날짜는 `timezone.now()` 기준 최근 3주 이내로 역산한 상대 날짜라 실행 시점에
따라 실제 달력 날짜가 달라진다. 모든 일지에 `backend/seedlings/fixtures/demo_photos/`의
실사진(SOURCE_PHOTO_NAMES)을 순환 배정해 photo 필드를 채운다 — `media/`는 `.gitignore`
대상이라 배포 환경(Render)에 없으므로 git으로 함께 배포되는 fixtures 경로를 쓴다.

## 센서 데이터
5개 묘목에 걸쳐 3~4건씩(총 18건). 묘목당 4건 이하라 항상 Prophet 최소치
(`sensor.anomaly.MIN_DATA_FOR_PROPHET` = 5)에 못 미쳐 전부 `_detect_by_threshold()`
(FALLBACK_RANGES 단순 비교: 온도 10~35 / 습도 30~90 / 조도 100~1000) 경로를 탄다.
이상치는 재배자 마이 탭 "환경 이상 감지 요약"(fl_chart 가로 막대)이 묘목별로 비교
가능하도록 편차를 줘서 넣었다 — #1에 2건(습도·조도), #3에 1건(온도), #5에 1건(습도),
#2·#4는 0건. `SensorDataCreateView.perform_create()`와 동일하게 `detect_anomaly()`/
`build_diagnosis_text()`를 실제로 호출해 저장한다(직접 `is_anomaly=True`를 박지 않는다).

## 폴리싱
- 완료 묘목 #4는 최종 키(`height_cm=32`)·`completed_at`·`pickup_or_donate`/`donate_type`를
  함께 채워, 로그인 즉시 기부 인증서 화면까지 바로 확인할 수 있게 한다.
- 5개 묘목 모두 `started_at`을 가장 오래된 일지보다 2일 앞선 날짜로 백데이트한다 —
  `auto_now_add=True`지만 `QuerySet.update()`는 이를 우회한다(`Diary.created_at` 백데이트와
  동일한 패턴). 안 하면 홈 화면 "함께한 지 N일째"가 전부 1일로 고정된다.
"""
from datetime import timedelta
from pathlib import Path

from django.core.files import File
from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from diary.models import Diary
from sensor.anomaly import build_diagnosis_text, detect_anomaly
from sensor.models import SensorData

from seedlings.models import Seedling

DEMO_PASSWORD = 'demo1234'

GROWER_EMAIL = 'grower@demo.com'
GROWER_NICKNAME = '박재배'

# 구버전 데모 입양자 — 한 번 정리되면 이후 실행에서는 no-op이 된다.
LEGACY_ADOPTER_EMAILS = [
    'adopter@demo.com', 'adopter2@demo.com',
    'dummy1@demo.com', 'dummy2@demo.com', 'dummy3@demo.com',
]

# (내부 키, 이메일, 닉네임)
ADOPTER_SPECS = [
    ('adopter1', 'adopter1@demo.com', '김하늘'),
    ('adopter2', 'adopter2@demo.com', '이서준'),
    ('adopter3', 'adopter3@demo.com', '박지우'),
    ('adopter4', 'adopter4@demo.com', '최민서'),
    ('adopter5', 'adopter5@demo.com', '정예린'),
]

# 묘목 스펙. status/height_cm/pickup·donate처럼 완료 묘목에만 있는 값이 늘어 dict로 둔다.
# started_days_ago는 그 묘목의 가장 오래된 일지보다 2일 이상 앞서야 한다(아래 일지 참고).
SEEDLING_SPECS = [
    {'key': 'seedling1', 'adopter': 'adopter1', 'status': Seedling.Status.GROWING,
     'started_days_ago': 13},
    {'key': 'seedling2', 'adopter': 'adopter2', 'status': Seedling.Status.GROWING,
     'started_days_ago': 17},
    {'key': 'seedling3', 'adopter': 'adopter3', 'status': Seedling.Status.GROWING,
     'started_days_ago': 21},
    {'key': 'seedling4', 'adopter': 'adopter4', 'status': Seedling.Status.COMPLETED,
     'started_days_ago': 25, 'completed_days_ago': 1, 'height_cm': 32,
     'pickup_or_donate': Seedling.PickupOrDonate.DONATE,
     'donate_type': Seedling.DonateType.URBAN_FARMING_COMMUNITY},
    {'key': 'seedling5', 'adopter': 'adopter5', 'status': Seedling.Status.GROWING,
     'started_days_ago': 19},
]

# backend/seedlings/fixtures/demo_photos/에 있는 실사진 중 순환 배정할 파일들.
SOURCE_PHOTO_NAMES = [
    'fig_real.jpg',
    'leaf.jpg',
    'scaled_KakaoTalk_20260721_154630614_01.jpg',
    'scaled_무화과사진.jpg',
]


class Command(BaseCommand):
    help = '포스터 캡처/데모용 계정·묘목·일지·센서 데이터를 생성한다 (입양자는 매번 삭제 후 재생성).'

    def handle(self, *args, **options):
        self.stdout.write('기존 데모 입양자 정리')
        self._reset_demo_adopters()

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
    # 초기화
    # ------------------------------------------------------------------

    def _reset_demo_adopters(self):
        """구버전 + 신버전 데모 입양자를 통째로 삭제한다(연결된 묘목/일지/센서/비전은 CASCADE).

        재배자(grower@demo.com)는 대상에 포함하지 않는다 — 이 스크립트가 매번 새로
        만드는 것은 입양자와 그 데이터뿐이고, 재배자는 아래 _seed_accounts()에서
        get_or_create로 그대로 유지된다.
        """
        emails = sorted(
            {*LEGACY_ADOPTER_EMAILS, *(email for _, email, _ in ADOPTER_SPECS)}
        )
        deleted, per_model = User.objects.filter(email__in=emails).delete()
        if deleted:
            self.stdout.write(self.style.SUCCESS(
                f'  삭제: 총 {deleted}건 ({dict(per_model)})',
            ))
        else:
            self.stdout.write('  삭제할 기존 데모 입양자 없음')

    # ------------------------------------------------------------------
    # 계정
    # ------------------------------------------------------------------

    def _seed_accounts(self):
        accounts = {
            'grower': self._get_or_create_user(
                GROWER_EMAIL, User.Role.GROWER, GROWER_NICKNAME,
            ),
        }
        for key, email, nickname in ADOPTER_SPECS:
            accounts[key] = self._get_or_create_user(
                email, User.Role.ADOPTER, nickname,
            )
        return accounts

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
        for spec in SEEDLING_SPECS:
            seedlings[spec['key']] = self._create_seedling(
                accounts[spec['adopter']], grower, spec,
            )
        return seedlings

    def _create_seedling(self, adopter, grower, spec):
        seedling = Seedling.objects.create(
            adopter=adopter, grower=grower, status=spec['status'],
        )
        now = timezone.now()
        # started_at은 auto_now_add=True지만 QuerySet.update()는 pre_save를 거치지
        # 않아 그대로 덮어써진다(Diary.created_at 백데이트와 동일한 패턴).
        updates = {'started_at': now - timedelta(days=spec['started_days_ago'])}
        if spec['status'] == Seedling.Status.COMPLETED:
            updates.update(
                completed_at=now - timedelta(days=spec.get('completed_days_ago', 1)),
                height_cm=spec.get('height_cm'),
                pickup_or_donate=spec.get('pickup_or_donate'),
                donate_type=spec.get('donate_type'),
            )
        Seedling.objects.filter(pk=seedling.pk).update(**updates)
        seedling.refresh_from_db()
        self.stdout.write(self.style.SUCCESS(
            f'  생성: 묘목 #{seedling.pk} '
            f'({adopter.nickname}, {seedling.get_status_display()})',
        ))
        return seedling

    # ------------------------------------------------------------------
    # 일지 + 사진
    # ------------------------------------------------------------------

    def _load_source_photos(self):
        # media/는 .gitignore 대상이라 배포 환경에 없다 — git으로 함께 배포되는
        # 앱 코드 안의 fixtures 경로(backend/seedlings/fixtures/demo_photos/)에서 읽는다.
        photos_dir = Path(__file__).resolve().parent.parent.parent / 'fixtures' / 'demo_photos'
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
        # 리스트의 마지막(가장 최근) 항목의 growth_stage가 그 묘목의 "표시 단계"가 된다.
        self._seed_diaries_for_seedling(seedlings['seedling1'], grower, [
            (11, Diary.GrowthStage.ROOTING,
             '입양해 주셔서 고마워요! 오늘 햇빛이 잘 드는 자리에 화분을 놓고 첫 물을 흠뻑 줬어요. '
             '뿌리가 자리 잡을 때까지 바람이 직접 닿지 않게 신경 쓸게요.'),
            (6, Diary.GrowthStage.ROOTING,
             '겉흙이 마를 때만 조금씩 물을 주고 있어요. 눈에 띄는 변화는 없지만 줄기 아랫부분이 '
             '단단해진 느낌이라 뿌리가 힘을 내는 것 같습니다.'),
            (1, Diary.GrowthStage.ROOTING,
             '드디어 흙 위로 자그마한 새순이 얼굴을 내밀었어요! 발근이 잘 되고 있다는 신호라 '
             '한시름 놓았습니다 🌱'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling2'], grower, [
            (15, Diary.GrowthStage.ROOTING,
             '새 무화과 묘목을 데려온 첫날이에요. 뿌리 활착이 먼저라 당분간 물 관리에만 집중하겠습니다.'),
            (10, Diary.GrowthStage.ROOTING,
             '아침저녁으로 상태를 살피고 있어요. 흙을 살짝 눌러보니 뿌리가 힘이 생긴 것 같아 '
             '물 주는 간격을 조금 늘렸습니다.'),
            (4, Diary.GrowthStage.LEAFING,
             '첫 잎이 활짝 펼쳐졌어요! 손톱만 하던 잎눈이 며칠 사이 쑥 자라서 깜짝 놀랐습니다.'),
            (1, Diary.GrowthStage.LEAFING,
             '잎이 두 장 더 나왔어요. 초록빛이 하루가 다르게 짙어지고 있어서 물 주는 손이 즐겁습니다 🍃'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling3'], grower, [
            (19, Diary.GrowthStage.ROOTING,
             '입양 첫 기록이에요. 작은 묘목이지만 자세히 보면 벌써 생기가 돌아서 키우는 재미가 있겠어요.'),
            (13, Diary.GrowthStage.ROOTING,
             '뿌리가 안정된 것 같아 물 주기를 이틀에 한 번으로 줄였어요. 새순도 튼튼하게 자리 잡았습니다.'),
            (7, Diary.GrowthStage.LEAFING,
             '잎이 제법 넓어졌어요. 햇볕을 골고루 받도록 화분을 매일 조금씩 돌려주고 있습니다.'),
            (2, Diary.GrowthStage.BRANCHING,
             '드디어 곁가지가 갈라지기 시작했어요! 줄기도 단단해져서 이제 제법 나무 티가 납니다 🌿'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling4'], grower, [
            (23, Diary.GrowthStage.ROOTING,
             '입양 첫날입니다. 뿌리부터 차근차근, 서두르지 않고 키워볼게요.'),
            (16, Diary.GrowthStage.LEAFING,
             '잎이 여러 장 펼쳐지면서 화분이 한결 풍성해졌어요. 벌레는 없는지 잎 뒷면도 꼼꼼히 살피고 있습니다.'),
            (8, Diary.GrowthStage.BRANCHING,
             '가지가 세 갈래로 뻗었어요. 바람에 흔들려도 끄떡없을 만큼 줄기가 단단해졌습니다.'),
            (2, Diary.GrowthStage.MATURE,
             '무성한 잎과 가지로 어엿한 묘목이 완성됐어요! 그동안 함께 지켜봐 주셔서 감사합니다 🌳'),
        ])
        self._seed_diaries_for_seedling(seedlings['seedling5'], grower, [
            (17, Diary.GrowthStage.ROOTING,
             '새 식구를 맞았어요. 첫 2주는 뿌리 내리기에만 집중하겠습니다.'),
            (11, Diary.GrowthStage.ROOTING,
             '겉흙이 마를 때만 물을 줬는데 새순이 쑥 올라왔어요. 생각보다 활착이 빠릅니다.'),
            (5, Diary.GrowthStage.LEAFING,
             '잎이 넓게 자라 화분에 그늘이 질 정도가 됐어요. 성장 속도가 눈에 띄게 빠릅니다.'),
            (2, Diary.GrowthStage.BRANCHING,
             '곁가지가 나기 시작했어요! 가지 사이로 작은 잎눈도 보여서 다음이 더 기대됩니다 🌿'),
        ])

    def _seed_diaries_for_seedling(self, seedling, grower, entries):
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
        # 조도 100~1000. 묘목당 4건 이하라 항상 Prophet 최소치(5건) 미만이라
        # detect_anomaly()는 매번 단순 임계값 비교로만 판정한다.
        self._seed_sensor_data_for_seedling(seedlings['seedling1'], [
            (5, 22.0, 63.0, 520.0),
            (3, 23.0, 64.0, 545.0),
            (1, 21.0, 95.0, 530.0),    # 이상: 습도
            (0, 22.0, 66.0, 1350.0),   # 이상: 조도
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling2'], [
            (4, 22.0, 62.0, 500.0),
            (2, 23.0, 64.0, 515.0),
            (0, 22.0, 63.0, 505.0),
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling3'], [
            (6, 23.0, 60.0, 500.0),
            (4, 24.0, 62.0, 490.0),
            (2, 7.5, 61.0, 505.0),     # 이상: 온도
            (0, 22.0, 63.0, 498.0),
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling4'], [
            (5, 22.0, 61.0, 520.0),
            (3, 23.0, 63.0, 500.0),
            (1, 22.0, 62.0, 510.0),
        ])
        self._seed_sensor_data_for_seedling(seedlings['seedling5'], [
            (6, 21.0, 60.0, 490.0),
            (4, 22.0, 62.0, 505.0),
            (2, 23.0, 61.0, 500.0),
            (0, 22.0, 93.0, 495.0),    # 이상: 습도
        ])

    def _seed_sensor_data_for_seedling(self, seedling, readings):
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
        self.stdout.write('=== 데모 계정 (비밀번호 전부 demo1234) ===')
        self.stdout.write(
            f"  재배자   : {accounts['grower'].email}  (닉네임 박재배, 묘목 5그루 담당)",
        )
        rows = [
            ('adopter1', 'seedling1', '김하늘', '발근 중 · 재배중'),
            ('adopter2', 'seedling2', '이서준', '잎 성장 중 · 재배중'),
            ('adopter3', 'seedling3', '박지우', '가지 발달 · 재배중'),
            ('adopter4', 'seedling4', '최민서', '묘목 완성 · 완료·기부(도시농업 공동체)'),
            ('adopter5', 'seedling5', '정예린', '가지 발달 · 재배중'),
        ]
        for account_key, seedling_key, nickname, desc in rows:
            self.stdout.write(
                f"  {accounts[account_key].email}  "
                f"(닉네임 {nickname}, 묘목 #{seedlings[seedling_key].pk} — {desc})",
            )
