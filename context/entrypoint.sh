#!/bin/sh

set -e

if [ -n "$*" ]; then
    exec "$*"
fi

# Create secret file if not exist
if [ -n "$SECRET_KEY" ] && [ ! -f "$BASE_DIR/secret.txt" ]; then
    echo "$SECRET_KEY" > "${SECRET_FILE:-$BASE_DIR/secret.txt}"
fi

# first run
if [ ! -e "$ETESYNC_DB_PATH" ] || [ -z "$ETESYNC_DB_PATH/db.sqlite3" ]; then
    # always create secret file on first run when key provided
    if [ -n "$SECRET_KEY" ]; then
        echo "$SECRET_KEY" > "${SECRET_FILE:-$BASE_DIR/secret.txt}"
    fi

    echo 'Create Database'
    "$BASE_DIR"/manage.py migrate
    chown -R "$PUID":"$PGID" "$DATA_DIR"
    
    if [ "$SUPER_USER" ] && [ "$SUPER_EMAIL" ] && [ "$SUPER_PASS" ]; then
        echo 'Create Super User'
        echo "from django.contrib.auth.models import User; User.objects.create_superuser('$SUPER_USER','$SUPER_EMAIL','$SUPER_PASS')" | python manage.py shell
    fi
fi

if [ ! -e "$STATIC_DIR/static/admin" ] || [ ! -e "$STATIC_DIR/static/rest_framework" ]; then
    echo 'Static files are missing, running manage.py collectstatic...'
    mkdir -p "$STATIC_DIR/static"
    "$BASE_DIR"/manage.py collectstatic
    chown -R "$PUID":"$PGID" "$STATIC_DIR"
    chmod -R a=rX "$STATIC_DIR"
fi

if [ "$SERVER" = 'https' ] && { [ ! -f "$X509_CRT" ] || [ ! -f "$X509_KEY" ]; }; then
    echo "TLS is enabled, however neither the certificate nor the key were found!"
    echo "The correct paths are '$X509_CRT' and '$X509_KEY'"
    echo "Let's generate a selfsign certificate for localhost, but this isn't recommended"
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$X509_KEY" -out "$X509_CRT" -days 365 -subj '/CN=localhost'
fi

uWSGI="/usr/local/bin/uwsgi --ini ${BASE_DIR}/etesync.ini"

echo 'Starting ETESync'

if [ "$SERVER" = 'django-server' ]; then
    "$BASE_DIR"/manage.py runserver 0.0.0.0:"$PORT"
elif [ "$SERVER" = 'uwsgi' ]; then
    ${uWSGI}:uwsgi
elif [ "$SERVER" = 'http-socket' ]; then
    ${uWSGI}:http-socket
#elif [ $SERVER = 'http2' ]; then
#    ${uWSGI}:http2
elif [ "$SERVER" = 'https' ]; then
    ${uWSGI}:https
elif [ "$SERVER" = 'http' ]; then
    ${uWSGI}:http
fi
