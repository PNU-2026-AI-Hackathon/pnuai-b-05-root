from django.db import models

from seedlings.models import Seedling


class SensorData(models.Model):
    seedling = models.ForeignKey(
        Seedling,
        on_delete=models.CASCADE,
        related_name='sensor_data',
    )
    temperature = models.FloatField()
    humidity = models.FloatField()
    light = models.FloatField()
    recorded_at = models.DateTimeField(auto_now_add=True)
    is_anomaly = models.BooleanField(default=False)
    gemini_diagnosis = models.TextField(null=True, blank=True)

    def __str__(self):
        return f'SensorData #{self.pk} (seedling #{self.seedling_id})'
