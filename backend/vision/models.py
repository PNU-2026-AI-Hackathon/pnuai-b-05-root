from django.db import models

from diary.models import Diary


class VisionAnalysis(models.Model):
    diary = models.ForeignKey(
        Diary,
        on_delete=models.CASCADE,
        related_name='vision_analyses',
        null=True,
        blank=True,
    )
    image = models.ImageField(upload_to='vision/images/')
    result_tag = models.CharField(max_length=50)
    confidence = models.FloatField(default=0.0)
    location_info = models.CharField(max_length=100, null=True, blank=True)
    analyzed_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'VisionAnalysis #{self.pk} ({self.result_tag})'
