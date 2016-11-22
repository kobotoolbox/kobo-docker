#!/bin/bash
set -e

source /etc/profile

cd /srv/src/kpi

# This super long one-liner is to avoid issues with interactive python.
echo "import os; from django.contrib.auth.models import User; print 'UserExists' if User.objects.filter(username=os.environ['KOBO_SUPERUSER_USERNAME']).count() > 0 else User.objects.create_superuser(os.environ['KOBO_SUPERUSER_USERNAME'], 'kobo@example.com', os.environ['KOBO_SUPERUSER_PASSWORD'])" \
    | python manage.py shell --plain 2>&1
