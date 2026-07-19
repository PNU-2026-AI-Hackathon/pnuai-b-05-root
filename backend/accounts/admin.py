from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    model = User
    ordering = ('email',)
    list_display = ('email', 'role', 'is_staff', 'is_active', 'created_at')
    list_filter = ('role', 'is_staff', 'is_active')
    search_fields = ('email',)
    readonly_fields = ('created_at',)

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('권한 정보', {'fields': ('role', 'is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('기타', {'fields': ('created_at',)}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'role', 'password1', 'password2', 'is_staff', 'is_active'),
        }),
    )
