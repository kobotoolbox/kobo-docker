#!/bin/bash

[ -z "$DEFAULT_KOBO_USER" ] && exit 1

[ -z "$DEFAULT_KOBO_PASS" ] && exit 2

cd /srv/src/koboform

echo "from django.contrib.auth.models import User; print 'UserExists' if User.objects.filter(username='$DEFAULT_KOBO_USER').count() > 0 else User.objects.create_superuser('$DEFAULT_KOBO_USER', 'kobo@example.com', '$DEFAULT_KOBO_PASS');" \
    | python manage.py shell 2>&1


