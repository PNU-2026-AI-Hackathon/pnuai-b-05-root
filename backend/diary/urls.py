from django.urls import path

from .views import DiaryCreateView, DiaryDestroyView, DiaryListView

app_name = 'diary'

urlpatterns = [
    path('', DiaryCreateView.as_view(), name='create'),
    # 목록 조회의 <int:seedling_id>/와 패턴이 겹치지 않도록 entry/ 아래에 둔다.
    # (여기 정수는 seedling id가 아니라 일지 id다 — 아래 라우트와 의미가 다르다.)
    path('entry/<int:pk>/', DiaryDestroyView.as_view(), name='delete'),
    path('<int:seedling_id>/', DiaryListView.as_view(), name='list'),
]
