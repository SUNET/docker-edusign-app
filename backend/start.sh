#!/bin/sh

# Compose a few needed variables, and start the gunicorn
# daemon driving the edusign backend app.

set -e
set -x

edusign_name=${edusign_name-'edusign-webapp'}
base_dir=${base_dir-'/opt/edusign'}

log_dir=${log_dir-'/var/log/edusign'}
state_dir=${state_dir-"${base_dir}/run"}
workers=${workers-1}
worker_class=${worker_class-sync}
worker_threads=${worker_threads-1}
worker_timeout=${worker_timeout-30}
# Need to tell Gunicorn to trust the X-Forwarded-* headers
forwarded_allow_ips=${forwarded_allow_ips-'*'}

chown -R edusign: "${log_dir}" "${state_dir}"

extra_args=""

case $DEBUG in
  (true) extra_args="--reload"
esac

echo ""
echo "$0: Starting ${edusign_name}"

exec start-stop-daemon --start -c edusign:edusign --exec /usr/local/bin/uv --pidfile /opt/edusign/run/edusign-webapp.pid --user=edusign --group=edusign -- run gunicorn --bind 0.0.0.0:8080 --workers 1 --worker-class sync --threads 1 --timeout 30 '--forwarded-allow-ips=*' --access-logfile /var/log/edusign/edusign-webapp-access.log --error-logfile /var/log/edusign/edusign-webapp-error.log --capture-output --reload edusign_webapp.run:app

exec start-stop-daemon --start -c edusign:edusign --exec uv \
     --pidfile "${state_dir}/${edusign_name}.pid" \
     --user=edusign --group=edusign -- \
     run gunicorn \
     --bind 0.0.0.0:8080 \
     --workers ${workers} --worker-class ${worker_class} \
     --threads ${worker_threads} --timeout ${worker_timeout} \
     --forwarded-allow-ips="${forwarded_allow_ips}" \
     --access-logfile "${log_dir}/${edusign_name}-access.log" \
     --error-logfile "${log_dir}/${edusign_name}-error.log" \
     --capture-output \
     ${extra_args} \
     edusign_webapp.run:app
