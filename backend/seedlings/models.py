from django.conf import settings
from django.db import models


class Seedling(models.Model):
    class Status(models.TextChoices):
        GROWING = 'growing', '재배중'
        COMPLETED = 'completed', '완료'

    class PickupOrDonate(models.TextChoices):
        PICKUP = 'pickup', '수령'
        DONATE = 'donate', '기부'

    class DonateType(models.TextChoices):
        SCHOOL_WELFARE = 'school_welfare', '초등학교·복지시설 기증'
        URBAN_FARMING_COMMUNITY = 'urban_farming_community', '도시농업 공동체·시민단체 연계'
        IN_APP_SHARING = 'in_app_sharing', '앱 내 나눔 분양'

    adopter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='adopted_seedlings',
    )
    grower = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='growing_seedlings',
        null=True,
        blank=True,
    )
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.GROWING,
    )
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    # 완성 신고 시 재배자가 직접 입력하는 최종 수고(키, cm). 이 필드 도입 이전에 완료된
    # 묘목에는 값이 없으므로(마이그레이션으로 소급 불가) null=True, blank=True로 둔다 —
    # 새 완성 신고에서는 SeedlingCompleteSerializer가 required로 강제한다.
    height_cm = models.PositiveSmallIntegerField(null=True, blank=True)
    # 완성 신고 시 재배자가 올리는 최종 사진과, 그것을 Gemini로 변환한 동화풍 일러스트.
    # diary.Diary의 photo/illustration과 동일한 패턴(변환 실패/미설정 시 illustration만 비어 있음).
    final_photo = models.ImageField(
        upload_to='seedlings/final_photos/', null=True, blank=True,
    )
    final_illustration = models.ImageField(
        upload_to='seedlings/final_illustrations/', null=True, blank=True,
    )
    pickup_or_donate = models.CharField(
        max_length=10,
        choices=PickupOrDonate.choices,
        null=True,
        blank=True,
    )
    donate_type = models.CharField(
        max_length=50,
        choices=DonateType.choices,
        null=True,
        blank=True,
    )

    def __str__(self):
        return f'Seedling #{self.pk} ({self.status})'
