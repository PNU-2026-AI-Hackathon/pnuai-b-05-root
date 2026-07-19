from django.conf import settings
from django.db import models


class Seedling(models.Model):
    class Status(models.TextChoices):
        GROWING = 'growing', '재배중'
        COMPLETED = 'completed', '완료'

    class PickupOrDonate(models.TextChoices):
        PICKUP = 'pickup', '수령'
        DONATE = 'donate', '기부'

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
    pickup_or_donate = models.CharField(
        max_length=10,
        choices=PickupOrDonate.choices,
        null=True,
        blank=True,
    )
    donate_type = models.CharField(max_length=50, null=True, blank=True)

    def __str__(self):
        return f'Seedling #{self.pk} ({self.status})'
