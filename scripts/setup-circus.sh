#!/bin/bash

apt-install-if-needed circus

cat > /tmp/taiga-circus.ini <<EOF
[watcher:taiga]
working_dir = /home/$USER/taiga-back
cmd = gunicorn
args = -w 3 -t 60 --pythonpath=. -b 127.0.0.1:8001 taiga.wsgi
uid = $USER
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/$USER/logs/gunicorn.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 4
stderr_stream.class = FileStream
stderr_stream.filename = /home/$USER/logs/gunicorn.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 4

[env:taiga]
PATH = /home/$USER/.virtualenvs/taiga/bin:$PATH
TERM=rxvt-256color
SHELL=/bin/bash
USER=taiga
LANG=en_US.UTF-8
HOME=/home/$USER
PYTHONPATH=/home/$USER/.local/lib/python3.5/site-packages

[watcher:taiga-celery]
working_dir = /home/$USER/taiga-back
cmd = celery
args = -A taiga worker -c 4
uid = $USER
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/$USER/logs/celery.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 4
stderr_stream.class = FileStream
stderr_stream.filename = /home/$USER/logs/celery.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 4

[env:taiga-celery]
PATH = /home/$USER/.virtualenvs/taiga/bin:$PATH
TERM=rxvt-256color
SHELL=/bin/bash
USER=taiga
LANG=en_US.UTF-8
HOME=/home/$USER
PYTHONPATH=/home/$USER/.local/lib/python3.5/site-packages

[watcher:taiga-events]
working_dir = /home/$USER/taiga-events
cmd = /usr/local/bin/coffee
args = index.coffee
uid = taiga
numprocesses = 1
autostart = true
send_hup = true
stdout_stream.class = FileStream
stdout_stream.filename = /home/$USER/logs/taigaevents.stdout.log
stdout_stream.max_bytes = 10485760
stdout_stream.backup_count = 12
stderr_stream.class = FileStream
stderr_stream.filename = /home/$USER/logs/taigaevents.stderr.log
stderr_stream.max_bytes = 10485760
stderr_stream.backup_count = 12

EOF

if [ ! -e ~/.setup/circus ]; then
    sudo mv /tmp/taiga-circus.ini /etc/circus/conf.d/taiga.ini

    sudo service circusd restart
    touch ~/.setup/circus
fi

circusctl reloadconfig

circusctl start taiga
circusctl start taiga-celery
circusctl start taiga-events

circusctl restart taiga
circusctl restart taiga-celery
circusctl restart taiga-events