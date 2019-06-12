#!/usr/bin/env bash

if [ "$#" -ne 0 ]; then
    exec "$@"
else
    num_retries=0
    until psql -c "select 1" postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST/$POSTGRES_DB > /dev/null 2>&1; do
        echo "Waiting for postgres server...($((num_retries++))s)"
        sleep 1
    done

    set -ex
    fabmanager create-admin --username superset \
        --firstname superset \
        --lastname apache \
        --email superset@gunosy.com \
        --password superset \
        --app superset
    superset db upgrade
    # superset load_examples
    superset init
    celery worker --app=superset.sql_lab:celery_app --pool=gevent -Ofair &
    gunicorn --bind  0.0.0.0:8088 \
        --workers $((2 * $(getconf _NPROCESSORS_ONLN) + 1)) \
        --timeout 60 \
        --limit-request-line 0 \
        --limit-request-field_size 0 \
        superset:app
fi

