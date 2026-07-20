from django.urls import path

from .views import ChatbotAskView

app_name = 'chatbot'

urlpatterns = [
    path('ask/', ChatbotAskView.as_view(), name='ask'),
]
