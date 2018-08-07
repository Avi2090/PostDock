#!/usr/bin/env bash
set -e
FORCE_RECONFIGURE=1 postgres_configure

echo ">>> Creating replication user '$REPLICATION_USER'"
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE ROLE $REPLICATION_USER WITH REPLICATION PASSWORD '$REPLICATION_PASSWORD' SUPERUSER CREATEDB  CREATEROLE INHERIT LOGIN;"

echo ">>> Creating replication db '$REPLICATION_DB'"
createdb $REPLICATION_DB -O $REPLICATION_USER

### update pod label for master : role: primary
cat > patch.json <<EOF
[ 
 { 
 "op": "add", "path": "/metadata/labels/role", "value": "primary" 
 } 
]
EOF

KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
curl -k --header "Authorization: Bearer $KUBE_TOKEN" --request PATCH --data "$(cat patch.json)" \
  -H "Content-Type:application/json-patch+json" \
  https://kubernetes.default.svc:443/api/v1/namespaces/${MY_POD_NAMESPACE}/pods/${MY_POD_NAME}

####

#TODO: make it more flexible, allow set of IPs
# Why db_name='replication' - https://dba.stackexchange.com/questions/82351/postgresql-doesnt-accept-replication-connection
echo "host replication $REPLICATION_USER 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf
