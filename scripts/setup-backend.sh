#!/bin/bash

BACKEND_VERSION="stable"

pushd ~

cat > /tmp/settings.py <<EOF
from .common import *
from .celery import *

MEDIA_URL = "/media/"
STATIC_URL = "/static/"

# This should change if you want generate urls in emails
# for external dns.
SITES["front"]["domain"] = "localhost:8000" # colocar URL de verdade

DEBUG = True
PUBLIC_REGISTER_ENABLED = True

DEFAULT_FROM_EMAIL = "no-reply@example.com"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

#EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
#EMAIL_USE_TLS = False
#EMAIL_HOST = "localhost"
#EMAIL_HOST_USER = ""
#EMAIL_HOST_PASSWORD = ""
#EMAIL_PORT = 25

BROKER_URL = 'amqp://guest:guest@localhost:5672//'
CELERY_RESULT_BACKEND = 'redis://localhost:6379/0'
CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = "taiga.events.backends.rabbitmq.EventsPushBackend"
EVENTS_PUSH_BACKEND_OPTIONS = {"url": "amqp://taiga:taiga@localhost:5672/taiga"}


INSTALLED_APPS += ["taiga_contrib_ldap_auth"]

LDAP_SERVER = 'ldap://ldap.example.com'
LDAP_PORT = 389

# Full DN of the service account use to connect to LDAP server and search for login user's account entry
# If LDAP_BIND_DN is not specified, or is blank, then an anonymous bind is attempated
LDAP_BIND_DN = 'CN=SVC Account,OU=Service Accounts,OU=Servers,DC=example,DC=com'
LDAP_BIND_PASSWORD = 'replace_me'   # eg.
# Starting point within LDAP structure to search for login user
LDAP_SEARCH_BASE = 'OU=DevTeam,DC=example,DC=net'
# LDAP property used for searching, ie. login username needs to match value in sAMAccountName property in LDAP
LDAP_SEARCH_PROPERTY = 'sAMAccountName'
LDAP_SEARCH_SUFFIX = None # '@example.com'

# Names of LDAP properties on user account to get email and full name
LDAP_EMAIL_PROPERTY = 'mail'
LDAP_FULL_NAME_PROPERTY = 'name'
EOF

cat > /tmp/config.events.json <<EOF
{
    "url": "amqp://taiga:taiga@localhost:5672/taiga",
    "secret": "mysecret",
    "webSocketServer": {
        "port": 8888
    }
}

EOF

if [ ! -e ~/taiga-back ]; then
    createdb-if-needed taiga
    git clone https://github.com/taigaio/taiga-back.git taiga-back
    git clone https://github.com/taigaio/taiga-events.git taiga-events

    pushd ~/taiga-back
    git checkout -f stable

    rabbit-create-user-if-needed taiga taiga  # username, password
    rabbit-create-vhost-if-needed taiga
    rabbit-set-permissions taiga taiga ".*" ".*" ".*" # username, vhost, configure, read, write
    mkvirtualenv-if-needed taiga

    pip install -r requirements.txt
    pip install taiga-contrib-ldap-auth # LDAP
    
    python manage.py migrate --noinput
    python manage.py compilemessages
    python manage.py collectstatic --noinput
    python manage.py loaddata initial_user
    python manage.py loaddata initial_project_templates
    python manage.py loaddata initial_role
    python manage.py sample_data

    # Settings
    mv /tmp/settings.py settings/local.py
    workon taiga

    popd
    
    pushd ~/taiga-events
    npm install
    npm-install-global coffee-script

    mv /tmp/config.events.json config.json
    
    # coffee index.coffee
    
    deactivate
    popd
else
    pushd ~/taiga-back
    git fetch
    git checkout -f stable
    git reset --hard origin/stable

    workon taiga
    pip install -r requirements.txt
    python manage.py migrate --noinput
    python manage.py compilemessages
    python manage.py collectstatic --noinput
    sudo service circus restart
    popd
fi

popd
