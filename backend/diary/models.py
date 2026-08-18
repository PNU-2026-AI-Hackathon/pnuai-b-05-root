from django.conf import settings
from django.db import models

from seedlings.models import Seedling


class Diary(models.Model):
    class GrowthStage(models.TextChoices):
        ROOTING = 'rooting', '발근 중'
        LEAFING = 'leafing', '잎 성장 중'
        BRANCHING = 'branching', '가지 발달'
        MATURE = 'mature', '묘목 완성'

    seedling = models.ForeignKey(
        Seedling,
        on_delete=models.CASCADE,
        related_name='diaries',
    )
    grower = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='diaries',
    )
    content = models.TextField()
    photo = models.ImageField(upload_to='diary/photos/', null=True, blank=True)
    illustration = models.ImageField(upload_to='diary/illustrations/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    yolo_status_tag = models.CharField(max_length=50, null=True, blank=True)
    # 재배자가 일지 작성 시 선택하는 성장 단계. 이 필드 도입 이전 일지에는 값이
    # 없으므로(마이그레이션으로 기존 행을 소급 채울 방법이 없음) seedlings.Seedling의
    # pickup_or_donate/donate_type과 동일하게 null=True, blank=True로 둔다.
    growth_stage = models.CharField(
        max_length=20,
        choices=GrowthStage.choices,
        null=True,
        blank=True,
    )

    def __str__(self):
        return f'Diary #{self.pk} (seedling #{self.seedling_id})'
