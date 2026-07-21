from django.conf import settings
from django.db import models

from seedlings.models import Seedling


class Diary(models.Model):
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

    def __str__(self):
        return f'Diary #{self.pk} (seedling #{self.seedling_id})'
