from django.urls import path

from .views import VisionAnalyzeView

app_name = 'vision'

urlpatterns = [
    path('analyze/', VisionAnalyzeView.as_view(), name='analyze'),
]
