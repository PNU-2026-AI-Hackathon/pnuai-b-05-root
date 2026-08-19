from django.urls import path

from .views import AccountView, LoginView, RegisterView

app_name = 'accounts'

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('me/', AccountView.as_view(), name='me'),
]
