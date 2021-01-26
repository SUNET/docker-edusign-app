#!/bin/sh

# Compose a few needed variables, and start the gunicorn
# daemon driving the edusign backend app.

set -e
set -x

. /opt/edusign/edusign-webapp/venv/bin/activate

edusign_name=${edusign_name-'edusign-webapp'}
app_name=${app_name-'webapp'}
base_dir=${base_dir-'/opt/edusign'}
project_dir=${project_dir-"${base_dir}/edusign-webapp/src"}

log_dir=${log_dir-'/var/log/edusign'}
state_dir=${state_dir-"${base_dir}/run"}
workers=${workers-1}
worker_class=${worker_class-sync}
worker_threads=${worker_threads-1}
worker_timeout=${worker_timeout-30}
# Need to tell Gunicorn to trust the X-Forwarded-* headers
forwarded_allow_ips=${forwarded_allow_ips-'*'}

chown -R edusign: "${log_dir}" "${state_dir}"

# set PYTHONPATH if it is not already set using Docker environment
export PYTHONPATH=${PYTHONPATH-${project_dir}}
echo "PYTHONPATH=${PYTHONPATH}"

# nice to have in docker run output, to check what
# version of something is actually running.
/opt/edusign/edusign-webapp/venv/bin/pip freeze

echo ""
echo "$0: Starting ${edusign_name}"

exec start-stop-daemon --start -c edusign:edusign --exec \
     /opt/edusign/edusign-webapp/venv/bin/gunicorn \
     --pidfile "${state_dir}/${edusign_name}.pid" \
     --user=edusign --group=edusign -- \
     --bind 0.0.0.0:8080 \
     --workers ${workers} --worker-class ${worker_class} \
     --threads ${worker_threads} --timeout ${worker_timeout} \
     --forwarded-allow-ips="${forwarded_allow_ips}" \
     --access-logfile "${log_dir}/${edusign_name}-access.log" \
     --error-logfile "${log_dir}/${edusign_name}-error.log" \
     --capture-output \
     edusign_webapp.run:app
