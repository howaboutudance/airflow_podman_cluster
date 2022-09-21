
set +e

NETWORK_NAME=airflow_network
declare -a POD_NAMES=("postgres" "redis" "airflow-init" "airflow-scheduler"
    "airflow-ui" "airflow-worker-1" "celery-flower" "statsd_export")

if podman network exists ${NETWORK_NAME}; then
    for instance in ${POD_NAMES[@]}; do
        if podman pod exists ${instance}; then
            podman pod kill ${instance}
            podman pod rm ${instance}
        else
            echo "${instance} pod does not exist in netowrk ${NETWORK_NAME}"
        fi
    done
    podman network rm ${NETWORK_NAME}
else
    echo "${NETWORK_NAME} does not exists... exiting..."
fi