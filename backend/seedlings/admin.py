from django.contrib import admin

from .models import Seedling


@admin.register(Seedling)
class SeedlingAdmin(admin.ModelAdmin):
    list_display = ('id', 'adopter', 'grower', 'status', 'started_at')
