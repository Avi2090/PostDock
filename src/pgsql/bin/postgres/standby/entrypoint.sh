#!/usr/bin/env bash
set -e

wait_upstream_postgres

if [ `ls $PGDATA/ | wc -l` != "0" ]; then
    echo ">>> Data folder is not empty $PGDATA:"
    ls -al $PGDATA
    if [[ "$CLEAN_OVER_REWIND" == "1" ]] && [[ "$MASTER_SLAVE_SWITCH" == "1" ]]; then
        echo ">>> Cleaning data folder..."
        rm -rf $PGDATA/*
    fi
fi

echo ">>> Starting standby node..."
if ! has_pg_cluster; then
    echo ">>> Instance hasn't been set up yet."
    do_master_clone
else
    echo ">>> Instance has been set up already."
    do_rewind
fi

rm -f $MASTER_ROLE_LOCK_FILE_NAME # that file should not be here anyways

### update pod label for standby : role: standby
cat > patch.json <<EOF
[
 {
 "op": "add", "path": "/metadata/labels/role", "value": "standby"
 }
]
EOF

KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
curl -k --header "Authorization: Bearer $KUBE_TOKEN" --request PATCH --data "$(cat patch.json)" \
  -H "Content-Type:application/json-patch+json" \
  https://kubernetes.default.svc:443/api/v1/namespaces/${MY_POD_NAMESPACE}/pods/${MY_POD_NAME}

####


postgres_configure

echo ">>> Starting postgres..."
exec gosu postgres postgres &
