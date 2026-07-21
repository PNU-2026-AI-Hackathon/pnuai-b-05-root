from django.urls import path

from .views import AccountDeleteView, LoginView, RegisterView

app_name = 'accounts'

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('me/', AccountDeleteView.as_view(), name='delete-account'),
]
