"""로컬 개발/데모용 시드 데이터 생성 커맨드.

python manage.py seed_demo

DB가 비어 있어 프론트엔드 화면이 전부 빈 상태로 보일 때, 앱 전체 흐름(입양자 홈/성장
타임라인/AI 챗봇, 재배자 대시보드/일지/환경점검)을 바로 확인할 수 있도록 계정 3개 +
묘목 3개 + 일지 3건 + 센서 데이터 6건을 만든다.

멱등하게 동작한다: 이메일이 이미 있는 계정, (입양자, 재배자, 상태) 조합이 이미 있는
묘목, 일지/센서 데이터가 하나라도 있는 묘목은 건너뛴다. 실패 후 재실행해도 이미 만든
데이터를 중복 생성하지 않는다.
"""
from datetime import datetime, timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from diary.models import Diary
from sensor.anomaly import build_diagnosis_text, detect_anomaly
from sensor.models import SensorData

from seedlings.models import Seedling

DEMO_PASSWORD = 'demo1234'


class Command(BaseCommand):
    help = '로컬 개발/데모용 계정·묘목·일지·센서 데이터를 생성한다 (멱등).'

    def handle(self, *args, **options):
        self.stdout.write('계정 생성')
        adopter = self._get_or_create_user('adopter@demo.com', User.Role.ADOPTER)
        adopter2 = self._get_or_create_user('adopter2@demo.com', User.Role.ADOPTER)
        grower = self._get_or_create_user('grower@demo.com', User.Role.GROWER)

        self.stdout.write('묘목 생성')
        seedling1 = self._get_or_create_seedling(
            adopter, grower, Seedling.Status.GROWING, '#1 (메인 데모, 재배중)',
        )
        self._get_or_create_seedling(
            adopter, grower, Seedling.Status.COMPLETED, '#2 (완성신고/수령기부 데모, 완료)',
        )
        seedling3 = self._get_or_create_seedling(
            adopter2, grower, Seedling.Status.GROWING, '#3 (다른 입양자, 재배중)',
        )

        self.stdout.write('일지 생성')
        self._seed_diaries(seedling1, grower)

        self.stdout.write('센서 데이터 생성')
        self._seed_sensor_data(seedling1)

        self.stdout.write(self.style.SUCCESS('시드 데이터 준비 완료'))
        self._print_summary(adopter, adopter2, grower, seedling1, seedling3)

    def _get_or_create_user(self, email, role):
        user = User.objects.filter(email=email).first()
        if user:
            self.stdout.write(f'  스킵 (이미 존재): {email}')
            return user
        user = User.objects.create_user(email=email, password=DEMO_PASSWORD, role=role)
        self.stdout.write(self.style.SUCCESS(f'  생성: {email} ({role})'))
        return user

    def _get_or_create_seedling(self, adopter, grower, status, label):
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
            )
            seedling.refresh_from_db()
        self.stdout.write(self.style.SUCCESS(f'  생성: 묘목 {label} -> #{seedling.pk}'))
        return seedling

    def _seed_diaries(self, seedling, grower):
        if Diary.objects.filter(seedling=seedling).exists():
            self.stdout.write(f'  스킵 (이미 존재): 묘목 #{seedling.pk} 일지')
            return

        year = timezone.now().year
        entries = [
            (6, 20, '입양 첫날, 새싹이 인사를 건네네요 🌱 떡잎 두 장이 참 야무집니다. 물은 흠뻑 줬어요.'),
            (7, 2, '첫 잎이 활짝 펴졌어요! 하루가 다르게 자라는 게 눈에 보입니다.'),
            (7, 18, '가지가 3개로 늘었어요! 오늘 새 가지에 힘이 붙었어요. 물은 아침에 흠뻑 줬습니다.'),
        ]
        for month, day, content in entries:
            diary = Diary.objects.create(seedling=seedling, grower=grower, content=content)
            created_at = timezone.make_aware(datetime(year, month, day, 9, 0))
            Diary.objects.filter(pk=diary.pk).update(created_at=created_at)
        self.stdout.write(self.style.SUCCESS(f'  생성: 묘목 #{seedling.pk} 일지 {len(entries)}건'))

    def _seed_sensor_data(self, seedling):
        if SensorData.objects.filter(seedling=seedling).exists():
            self.stdout.write(f'  스킵 (이미 존재): 묘목 #{seedling.pk} 센서 데이터')
            return

        now = timezone.now()
        # (며칠 전, 온도, 습도, 조도) — 마지막 한 건만 습도를 정상 범위(30~90) 안이지만
        # 직전 이력 대비 크게 튀는 값으로 넣어 Prophet 기반 이상 감지가 걸리게 한다.
        readings = [
            (5, 21.0, 63.0, 520.0),
            (4, 22.0, 65.0, 540.0),
            (3, 23.0, 64.0, 560.0),
            (2, 22.0, 66.0, 530.0),
            (1, 21.0, 65.0, 545.0),
            (0, 22.0, 85.0, 540.0),
        ]
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

    def _print_summary(self, adopter, adopter2, grower, seedling1, seedling3):
        self.stdout.write('')
        self.stdout.write('=== 데모 계정 ===')
        self.stdout.write(f'  입양자   : {adopter.email} / {DEMO_PASSWORD}  (묘목 #{seedling1.pk} 담당)')
        self.stdout.write(f'  입양자2  : {adopter2.email} / {DEMO_PASSWORD}  (묘목 #{seedling3.pk} 담당)')
        self.stdout.write(f'  재배자   : {grower.email} / {DEMO_PASSWORD}')
