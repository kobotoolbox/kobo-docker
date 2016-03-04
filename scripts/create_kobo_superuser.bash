#!/bin/bash
set -e

source /etc/profile

cd /srv/src/kpi

echo "from django.contrib.auth.models import User; print 'UserExists' if User.objects.filter(username='$KOBO_SUPERUSER_USERNAME').count() > 0 else User.objects.create_superuser('$KOBO_SUPERUSER_USERNAME', 'kobo@example.com', '$KOBO_SUPERUSER_PASSWORD');" \
    | python manage.py shell 2>&1
