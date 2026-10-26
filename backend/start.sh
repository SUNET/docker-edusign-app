#!/bin/sh

# Compose a few needed variables, and start the gunicorn
# daemon driving the edusign backend app.

set -e
set -x

. /opt/edusign/venv/bin/activate

edusign_name=${edusign_name-'edusign-webapp'}
base_dir=${base_dir-'/opt/edusign'}

log_dir=${log_dir-'/var/log/edusign'}
state_dir=${state_dir-"${base_dir}/run"}
# Gunicorn tuning, configurable via uppercase container env vars.
# The legacy lowercase names are kept as a fallback for compatibility.
workers=${GUNICORN_WORKERS-4}
worker_class=${GUNICORN_WORKER_CLASS-gthread}
worker_threads=${GUNICORN_WORKER_THREADS-4}
worker_timeout=${GUNICORN_WORKER_TIMEOUT-30}
# Checked here: gunicorn silently falls back to info on an unknown level.
log_level=$(echo "${GUNICORN_LOG_LEVEL:-info}" | tr '[:upper:]' '[:lower:]')
case $log_level in
  (debug|info|warning|error|critical) ;;
  (*) echo "$0: GUNICORN_LOG_LEVEL=$log_level: expected one of: debug info warning error critical" >&2
      exit 1 ;;
esac
# Need to tell Gunicorn to trust the X-Forwarded-* headers
forwarded_allow_ips=${forwarded_allow_ips-'*'}
# Several backend instances share the logs volume, so each needs its own log
# files. LOG_INSTANCE names this instance: a literal, or "hostname" for the
# container hostname. Empty: no instance part in the file names.
log_instance=${LOG_INSTANCE-}
if [ "${log_instance}" = "hostname" ]; then
   log_instance=$(hostname)
fi
log_name=${edusign_name}${log_instance:+-${log_instance}}

chown -R edusign: "${log_dir}" "${state_dir}"

extra_args=""

case $DEBUG in
  (true) extra_args="--reload"
esac

# nice to have in docker run output, to check what
# version of something is actually running.
/opt/edusign/venv/bin/pip freeze

echo ""
echo "$0: Starting ${edusign_name}"

exec start-stop-daemon --start -c edusign:edusign --exec \
     /opt/edusign/venv/bin/gunicorn \
     --pidfile "${state_dir}/${edusign_name}.pid" \
     --user=edusign --group=edusign -- \
     --bind 0.0.0.0:8080 \
     --workers ${workers} --worker-class ${worker_class} \
     --threads ${worker_threads} --timeout ${worker_timeout} \
     --forwarded-allow-ips="${forwarded_allow_ips}" \
     --access-logfile "${log_dir}/${log_name}-access.log" \
     --error-logfile "${log_dir}/${log_name}-error.log" \
     --capture-output \
     --log-level "${log_level}" \
     ${extra_args} \
     edusign_webapp.run:app
