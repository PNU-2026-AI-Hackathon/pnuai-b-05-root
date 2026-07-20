from django.urls import path

from .views import FCMTokenRegisterView, NotificationTestView

app_name = 'notifications'

urlpatterns = [
    path('register-token/', FCMTokenRegisterView.as_view(), name='register-token'),
    path('test/', NotificationTestView.as_view(), name='test'),
]
