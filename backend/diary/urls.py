from django.urls import path

from .views import DiaryCreateView, DiaryListView

app_name = 'diary'

urlpatterns = [
    path('', DiaryCreateView.as_view(), name='create'),
    path('<int:seedling_id>/', DiaryListView.as_view(), name='list'),
]
