#!/bin/sh
# Railway start script for Conductor: Postgres (state, queues, scheduler),
# Elasticsearch 8 (search index), Redis (workflow execution lock), and nginx
# with HTTP basic auth in front of the UI and API.
set -e

say() { echo "railway-template: $*"; }
die() { echo "railway-template: $*" >&2; exit 1; }

PORT="${PORT:-5000}"
DATA_DIR="${CONDUCTOR_DATA_DIR:-/app/data}"
UI_USER="${CONDUCTOR_USERNAME:-admin}"

[ -n "$CONDUCTOR_PASSWORD" ] || die "CONDUCTOR_PASSWORD is empty; refusing to expose Conductor without a login"
[ "$PORT" != "8080" ] || die "PORT must not be 8080 (the Conductor server's own port)"
for v in PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD ELASTICSEARCH_URL ELASTICSEARCH_PASSWORD REDIS_HOST REDIS_PORT; do
  eval "val=\${$v}"
  [ -n "$val" ] || die "$v is empty; check the template's reference variables"
done

mkdir -p "$DATA_DIR/files"
rm -rf "$DATA_DIR/lost+found" 2>/dev/null || true

# Wait for the other services (Railway starts them all at once on a fresh deploy).
wait_tcp() {
  host="$1"; port="$2"; name="$3"; i=0
  while ! nc -z -w 3 "$host" "$port" >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -le 100 ] || { say "$name ($host:$port) still not reachable; starting anyway"; return 0; }
    [ $((i % 10)) -eq 1 ] && say "waiting for $name at $host:$port"
    sleep 3
  done
  say "$name is reachable"
}
ES_HOSTPORT=$(echo "$ELASTICSEARCH_URL" | sed -E 's#^[a-z]+://##; s#/.*$##')
ES_HOST=$(echo "$ES_HOSTPORT" | sed -E 's/:[0-9]+$//; s/^\[//; s/\]$//')
ES_PORT=$(echo "$ES_HOSTPORT" | grep -oE ':[0-9]+$' | tr -d ':'); ES_PORT="${ES_PORT:-9200}"
wait_tcp "$PGHOST" "$PGPORT" Postgres
wait_tcp "$REDIS_HOST" "$REDIS_PORT" Redis
wait_tcp "$ES_HOST" "$ES_PORT" Elasticsearch
# Elasticsearch accepts connections before it can serve requests: wait for a yellow or green cluster.
i=0
until wget -q -O /dev/null --header "Authorization: Basic $(printf '%s' "elastic:$ELASTICSEARCH_PASSWORD" | base64 | tr -d '\n')" \
    "$ELASTICSEARCH_URL/_cluster/health?wait_for_status=yellow&timeout=5s" 2>/dev/null; do
  i=$((i + 1)); [ "$i" -le 60 ] || { say "Elasticsearch not healthy yet; starting anyway"; break; }
  sleep 5
done

# Conductor reads this file and sets each line as a Java system property.
CONF=/app/config/railway.properties
cat > "$CONF" <<PROPS
conductor.db.type=postgres
conductor.queue.type=postgres
conductor.external-payload-storage.type=postgres
spring.datasource.url=jdbc:postgresql://${PGHOST}:${PGPORT}/${PGDATABASE}
spring.datasource.username=${PGUSER}
spring.datasource.password=${PGPASSWORD}
conductor.indexing.enabled=true
conductor.indexing.type=elasticsearch8
conductor.elasticsearch.url=${ELASTICSEARCH_URL}
conductor.elasticsearch.username=${ELASTICSEARCH_USERNAME:-elastic}
conductor.elasticsearch.password=${ELASTICSEARCH_PASSWORD}
conductor.elasticsearch.indexName=conductor
conductor.elasticsearch.version=8
conductor.elasticsearch.clusterHealthColor=yellow
conductor.elasticsearch.indexShardCount=1
conductor.elasticsearch.indexReplicasCount=0
conductor.elasticsearch.indexRefreshInterval=1s
conductor.workflow-execution-lock.type=redis
conductor.app.workflowExecutionLockEnabled=true
conductor.app.lockTimeToTry=500
conductor.redis-lock.serverType=SINGLE
conductor.redis-lock.serverAddress=redis://${REDIS_HOST}:${REDIS_PORT}
conductor.redis-lock.serverUsername=${REDIS_USER:-default}
conductor.redis-lock.serverPassword=${REDIS_PASSWORD}
conductor.redis-lock.namespace=conductor
conductor.scheduler.enabled=true
conductor.app.ownerEmailMandatory=false
conductor.file-storage.enabled=true
conductor.file-storage.type=conductor
conductor.file-storage.conductor.directory=${DATA_DIR}/files
conductor.metrics-prometheus.enabled=true
management.endpoints.web.exposure.include=health,prometheus
server.forward-headers-strategy=native
loadSample=${CONDUCTOR_LOAD_SAMPLE:-false}
PROPS
[ -n "$REDIS_PASSWORD" ] || sed -i '/^conductor.redis-lock.server\(Username\|Password\)=/d' "$CONF"
chmod 600 "$CONF"

# nginx: UI and API behind basic auth; /health stays open for Railway's health check.
HASH=$(printf '%s' "$CONDUCTOR_PASSWORD" | openssl passwd -apr1 -stdin)
printf '%s:%s\n' "$UI_USER" "$HASH" > /etc/nginx/conductor.htpasswd
chown root:nginx /etc/nginx/conductor.htpasswd 2>/dev/null || true
chmod 640 /etc/nginx/conductor.htpasswd
cat > /etc/nginx/http.d/default.conf <<NGINX
server {
  listen ${PORT};
  listen [::]:${PORT};
  server_tokens off;
  client_max_body_size 100m;

  auth_basic "Conductor";
  auth_basic_user_file /etc/nginx/conductor.htpasswd;

  proxy_set_header Host \$http_host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
  proxy_read_timeout 300s;

  location = /health {
    auth_basic off;
    proxy_pass http://127.0.0.1:8080/health;
  }
  location /api { proxy_pass http://127.0.0.1:8080/api; }
  location /actuator { proxy_pass http://127.0.0.1:8080/actuator; }
  location /swagger-ui { proxy_pass http://127.0.0.1:8080/swagger-ui; }
  location /api-docs { proxy_pass http://127.0.0.1:8080/api-docs; }
  location / {
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    root /usr/share/nginx/html;
    try_files \$uri /index.html;
  }
}
NGINX
nginx -t -q
nginx
say "nginx on port $PORT (user '$UI_USER'); Conductor server on 8080 (private network, no auth)"

cd /app/libs
# Alpine/musl: same glibc-compat preload as upstream's startup.sh, for grpc-java.
export LD_PRELOAD=/lib/libgcompat.so.0:/usr/lib/libunwind.so.8
exec java ${JAVA_OPTS:--Xms256m -Xmx1g} -DCONDUCTOR_CONFIG_FILE="$CONF" -jar conductor-server.jar
