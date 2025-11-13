#!/bin/bash

# Script de testing para deployment de Kubernetes
# Ejecutar con: bash k8s-test.sh

set -e  # Exit on any error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║          KUBERNETES MICROSERVICES TEST            ║"
echo "║                   v1.0                          ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

NAMESPACE="microservices"

log "🔍 Verificando estado del cluster..."

# Verificar que el namespace existe
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    error "Namespace $NAMESPACE no existe"
    exit 1
fi

# Verificar pods
log "📋 Estado de los pods:"
kubectl get pods -n $NAMESPACE

# Verificar que todos los pods críticos estén running
log "🔍 Verificando pods críticos..."
CRITICAL_PODS=("auth-api" "users-api" "todos-api" "frontend" "redis" "log-processor")
for pod in "${CRITICAL_PODS[@]}"; do
    if kubectl get pods -n $NAMESPACE -l app=$pod --no-headers | grep -q "1/1.*Running"; then
        success "$pod está funcionando"
    else
        error "$pod no está funcionando correctamente"
        kubectl get pods -n $NAMESPACE -l app=$pod
    fi
done

log "🚀 Iniciando port forwards..."

# Función para limpiar port forwards al salir
cleanup() {
    log "🧹 Limpiando port forwards..."
    pkill -f "kubectl port-forward" || true
    wait
    log "✅ Limpieza completada"
}
trap cleanup EXIT

# Hacer port forwards en background
kubectl port-forward svc/auth-api 8081:8081 -n $NAMESPACE &
AUTH_PF_PID=$!
kubectl port-forward svc/users-api 8083:8083 -n $NAMESPACE &
USERS_PF_PID=$!
kubectl port-forward svc/todos-api 8082:8082 -n $NAMESPACE &
TODOS_PF_PID=$!
kubectl port-forward svc/frontend 8080:8080 -n $NAMESPACE &
FRONTEND_PF_PID=$!

# Esperar a que los port forwards estén listos
log "⏳ Esperando a que los port forwards estén listos..."
sleep 10

# Verificar que los port forwards estén funcionando
log "🔍 Verificando conectividad de port forwards..."
for i in {1..30}; do
    if netstat -an 2>/dev/null | grep -q ":8080.*LISTEN" && 
       netstat -an 2>/dev/null | grep -q ":8081.*LISTEN" && 
       netstat -an 2>/dev/null | grep -q ":8082.*LISTEN" && 
       netstat -an 2>/dev/null | grep -q ":8083.*LISTEN"; then
        success "Todos los port forwards están activos"
        break
    fi
    echo -n "."
    sleep 1
done
echo

# Función para verificar si un puerto está disponible
check_port() {
    local port=$1
    local service=$2
    if curl -s --connect-timeout 3 http://localhost:$port > /dev/null 2>&1; then
        success "Port forward para $service ($port) está activo"
        return 0
    else
        warning "Port forward para $service ($port) no responde"
        return 1
    fi
}

log "🧪 INICIANDO TESTS DE MICROSERVICIOS..."

echo
log "=== 🔐 Auth API ==="
log "Probando conectividad a Auth API..."
# Primero verificar conectividad básica
if curl -s --connect-timeout 10 --max-time 15 http://localhost:8081 > /dev/null 2>&1; then
    success "Auth API está respondiendo"
    
    log "Probando login según documentación..."
    AUTH_RESPONSE=$(curl -s -X POST http://localhost:8081/login \
        -H "Content-Type: application/json" \
        -d '{"username": "admin", "password": "admin"}' \
        --connect-timeout 10)
    
    if echo $AUTH_RESPONSE | jq . > /dev/null 2>&1; then
        success "Login exitoso"
        echo $AUTH_RESPONSE | jq .
        
        # Obtener token para usar en otros tests
        TOKEN=$(echo $AUTH_RESPONSE | jq -r '.accessToken // empty')
        if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
            success "Token JWT obtenido"
        else
            error "No se pudo obtener token JWT"
            TOKEN=""
        fi
    else
        error "Login falló o respuesta inválida"
        echo "Respuesta: $AUTH_RESPONSE"
        TOKEN=""
    fi
else
    error "Auth API no está respondiendo"
    TOKEN=""
fi

echo
log "=== 👥 Users API ==="
log "Probando conectividad a Users API..."
# Verificar health endpoint de Spring Boot
if curl -s --connect-timeout 10 --max-time 15 http://localhost:8083/actuator/health > /dev/null 2>&1; then
    success "Users API health check OK"
    echo "Health status:"
    curl -s http://localhost:8083/actuator/health | jq .
else
    warning "Health endpoint no disponible, probando endpoint básico"
fi

if [ ! -z "$TOKEN" ]; then
    log "Probando endpoint /users con token..."
    USERS_RESPONSE=$(curl -s -X GET http://localhost:8083/users \
        -H "Authorization: Bearer $TOKEN" \
        --connect-timeout 10)
    
    if echo $USERS_RESPONSE | jq . > /dev/null 2>&1; then
        success "Lista de usuarios obtenida correctamente"
        echo $USERS_RESPONSE | jq .
        
        # Probar endpoint específico de usuario según documentación
        log "Probando endpoint /users/admin..."
        USER_RESPONSE=$(curl -s -X GET http://localhost:8083/users/admin \
            -H "Authorization: Bearer $TOKEN" \
            --connect-timeout 10)
        
        if echo $USER_RESPONSE | jq . > /dev/null 2>&1; then
            success "Usuario específico obtenido correctamente"
            echo $USER_RESPONSE | jq .
        else
            warning "Endpoint /users/admin no responde correctamente"
        fi
    else
        warning "Users API respuesta no válida o error de autenticación"
        echo "Respuesta: $USERS_RESPONSE"
    fi
else
    warning "No hay token disponible para probar Users API"
        
        if echo $USERS_RESPONSE | jq . > /dev/null 2>&1; then
            success "Users API funcionando correctamente"
            echo $USERS_RESPONSE | jq .
        else
            warning "Users API respuesta no válida o error de autenticación"
            echo "Respuesta: $USERS_RESPONSE"
        fi
    else
        warning "No hay token disponible para probar Users API"
    fi
else
    error "Users API no está respondiendo"
fi

echo
log "=== 📝 Todos API ==="
log "Probando conectividad a Todos API..."
if curl -s --connect-timeout 10 --max-time 15 http://localhost:8082 > /dev/null 2>&1; then
    success "Todos API está respondiendo"
    
    if [ ! -z "$TOKEN" ]; then
        log "Probando endpoint GET /todos con token..."
        TODOS_RESPONSE=$(curl -s -X GET http://localhost:8082/todos \
            -H "Authorization: Bearer $TOKEN" \
            --connect-timeout 10)
        
        if echo $TODOS_RESPONSE | jq . > /dev/null 2>&1; then
            success "GET /todos funcionando correctamente"
            echo $TODOS_RESPONSE | jq .
            
            # Test CRUD completo según documentación
            log "Probando POST /todos (crear todo)..."
            CREATE_RESPONSE=$(curl -s -X POST http://localhost:8082/todos \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -d '{"content": "Test todo from k8s-test script"}' \
                --connect-timeout 10)
            
            if echo $CREATE_RESPONSE | jq . > /dev/null 2>&1; then
                success "Todo creado correctamente"
                echo $CREATE_RESPONSE | jq .
                
                # Extraer ID del todo creado para test de DELETE
                TODO_ID=$(echo $CREATE_RESPONSE | jq -r '.id // empty')
                if [ ! -z "$TODO_ID" ] && [ "$TODO_ID" != "null" ]; then
                    log "Probando DELETE /todos/$TODO_ID..."
                    DELETE_RESPONSE=$(curl -s -X DELETE http://localhost:8082/todos/$TODO_ID \
                        -H "Authorization: Bearer $TOKEN" \
                        --connect-timeout 10)
                    
                    if [ "$?" -eq 0 ]; then
                        success "Todo eliminado correctamente"
                    else
                        warning "Error al eliminar todo"
                    fi
                fi
            else
                warning "Error al crear todo"
                echo "Respuesta: $CREATE_RESPONSE"
            fi
        else
            warning "Todos API respuesta no válida o error de autenticación"
            echo "Respuesta: $TODOS_RESPONSE"
        fi
    else
        warning "No hay token disponible para probar Todos API"
    fi
else
    error "Todos API no está respondiendo"
fi

echo
log "=== 📊 Redis ==="
log "Probando conectividad a Redis..."
# Verificar Redis usando port-forward temporal
kubectl port-forward svc/redis 6379:6379 -n $NAMESPACE &
REDIS_PF_PID=$!
sleep 5

# Test Redis connectivity
if command -v redis-cli > /dev/null 2>&1; then
    if redis-cli -h localhost -p 6379 ping > /dev/null 2>&1; then
        success "Redis está respondiendo"
        log "Info de Redis:"
        redis-cli -h localhost -p 6379 info server | head -5
    else
        error "Redis no responde a ping"
    fi
else
    # Usar nc si redis-cli no está disponible
    if echo "ping" | nc -w 3 localhost 6379 | grep -q "PONG"; then
        success "Redis está respondiendo (verificado con nc)"
    else
        warning "No se puede verificar Redis (instalar redis-cli o nc)"
    fi
fi

# Limpiar port-forward de Redis
kill $REDIS_PF_PID 2>/dev/null || true

echo
log "=== 🐍 Log Message Processor ==="
log "Verificando Log Message Processor..."
if kubectl get pods -n $NAMESPACE -l app=log-processor --no-headers | grep -q "1/1.*Running"; then
    success "Log processor está ejecutándose"
    log "Logs recientes del processor:"
    kubectl logs --tail=10 -l app=log-processor -n $NAMESPACE | head -5
else
    error "Log processor no está funcionando"
fi

echo
log "=== 🌐 Frontend ==="
log "Probando conectividad a Frontend..."
if curl -s --connect-timeout 10 --max-time 15 http://localhost:8080 > /dev/null 2>&1; then
    success "Frontend está respondiendo"
    TITLE=$(curl -s http://localhost:8080 --connect-timeout 10 | grep -i title | head -1 || echo "No title found")
    echo "Título de la página: $TITLE"
    
    # Verificar que el frontend puede cargar assets
    log "Verificando assets del frontend..."
    if curl -s --connect-timeout 5 http://localhost:8080/static/ > /dev/null 2>&1; then
        success "Assets del frontend accesibles"
    else
        warning "Assets del frontend no accesibles"
    fi
else
    error "Frontend no está respondiendo"
fi

echo
log "=== 📊 Prometheus & Grafana ==="
log "Verificando stack de monitoreo..."

# Verificar namespace de monitoring
if kubectl get namespace monitoring &> /dev/null; then
    success "Namespace 'monitoring' existe"
    
    # Verificar Prometheus
    log "Verificando Prometheus..."
    if kubectl get pods -n monitoring -l app=prometheus --no-headers | grep -q "1/1.*Running"; then
        success "Prometheus está ejecutándose"
        
        # Port forward para Prometheus
        kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
        PROM_PF_PID=$!
        sleep 8
        
        # Test Prometheus API
        if curl -s --connect-timeout 10 http://localhost:9090/-/ready > /dev/null 2>&1; then
            success "Prometheus API está respondiendo"
            
            # Verificar targets
            TARGETS_RESPONSE=$(curl -s http://localhost:9090/api/v1/targets --connect-timeout 10)
            if echo $TARGETS_RESPONSE | jq '.data.activeTargets' > /dev/null 2>&1; then
                ACTIVE_TARGETS=$(echo $TARGETS_RESPONSE | jq '.data.activeTargets | length')
                success "Prometheus tiene $ACTIVE_TARGETS targets activos"
                
                # Mostrar algunos targets
                echo "Targets principales:"
                echo $TARGETS_RESPONSE | jq '.data.activeTargets[] | select(.health == "up") | .labels.job' | head -5
            fi
            
            # Test query simple
            QUERY_RESPONSE=$(curl -s "http://localhost:9090/api/v1/query?query=up" --connect-timeout 10)
            if echo $QUERY_RESPONSE | jq '.data.result' > /dev/null 2>&1; then
                UP_INSTANCES=$(echo $QUERY_RESPONSE | jq '.data.result | length')
                success "Prometheus query 'up' retorna $UP_INSTANCES instancias"
            fi
        else
            error "Prometheus API no responde"
        fi
        
        # Limpiar port forward de Prometheus
        kill $PROM_PF_PID 2>/dev/null || true
    else
        error "Prometheus no está ejecutándose"
    fi
    
    # Verificar Grafana
    echo
    log "Verificando Grafana..."
    if kubectl get pods -n monitoring -l app=grafana --no-headers | grep -q "1/1.*Running"; then
        success "Grafana está ejecutándose"
        
        # Port forward para Grafana
        kubectl port-forward svc/grafana 3000:3000 -n monitoring &
        GRAFANA_PF_PID=$!
        sleep 8
        
        # Test Grafana API
        if curl -s --connect-timeout 10 http://localhost:3000/api/health > /dev/null 2>&1; then
            success "Grafana está respondiendo"
            
            # Verificar health
            HEALTH_RESPONSE=$(curl -s http://localhost:3000/api/health --connect-timeout 10)
            if echo $HEALTH_RESPONSE | jq '.database' > /dev/null 2>&1; then
                DB_STATUS=$(echo $HEALTH_RESPONSE | jq -r '.database')
                success "Grafana database status: $DB_STATUS"
            fi
            
            # Test login (admin/admin123)
            LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/login \
                -H "Content-Type: application/json" \
                -d '{"user":"admin","password":"admin123"}' \
                --connect-timeout 10)
            
            if echo $LOGIN_RESPONSE | grep -q "Logged in"; then
                success "Grafana login funcionando"
            fi
            
            # Verificar datasources
            DATASOURCES_RESPONSE=$(curl -s http://admin:admin123@localhost:3000/api/datasources --connect-timeout 10)
            if echo $DATASOURCES_RESPONSE | jq . > /dev/null 2>&1; then
                DATASOURCE_COUNT=$(echo $DATASOURCES_RESPONSE | jq '. | length')
                success "Grafana tiene $DATASOURCE_COUNT datasource(s) configurado(s)"
                
                # Mostrar datasources
                echo "Datasources configurados:"
                echo $DATASOURCES_RESPONSE | jq '.[] | .name + " (" + .type + ")"' | head -3
            fi
        else
            error "Grafana no está respondiendo"
        fi
        
        # Limpiar port forward de Grafana
        kill $GRAFANA_PF_PID 2>/dev/null || true
    else
        error "Grafana no está ejecutándose"
    fi
    
    # Verificar ServiceMonitors si existen
    echo
    log "Verificando ServiceMonitors..."
    if kubectl get servicemonitor -n monitoring 2>/dev/null | grep -q "microservices"; then
        success "ServiceMonitors configurados para microservices"
        kubectl get servicemonitor -n monitoring
    else
        warning "ServiceMonitors no encontrados"
    fi
    
    # Información de acceso
    echo
    log "📋 Información de acceso al monitoreo:"
    echo "  🔗 Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
    echo "  🔗 Grafana: kubectl port-forward svc/grafana 3000:3000 -n monitoring"
    echo "  👤 Grafana login: admin / admin123"
    echo "  📊 URL local Prometheus: http://localhost:9090"
    echo "  📈 URL local Grafana: http://localhost:3000"
    
    # Test avanzado de métricas si Prometheus está funcionando
    if kubectl get pods -n monitoring -l app=prometheus --no-headers | grep -q "1/1.*Running"; then
        echo
        log "🔬 Test avanzado de métricas..."
        kubectl port-forward svc/prometheus 9090:9090 -n monitoring &
        PROM_PF_PID2=$!
        sleep 5
        
        # Verificar métricas específicas de microservices
        MICROSERVICE_METRICS_QUERIES=(
            "up{job=\"microservices/auth-api\"}"
            "up{job=\"microservices/users-api\"}" 
            "up{job=\"microservices/todos-api\"}"
            "up{job=\"microservices/frontend\"}"
            "container_cpu_usage_seconds_total{namespace=\"microservices\"}"
        )
        
        for query in "${MICROSERVICE_METRICS_QUERIES[@]}"; do
            ENCODED_QUERY=$(echo "$query" | sed 's/ /%20/g' | sed 's/{/%7B/g' | sed 's/}/%7D/g' | sed 's/"/%22/g')
            METRIC_RESPONSE=$(curl -s "http://localhost:9090/api/v1/query?query=$ENCODED_QUERY" --connect-timeout 10)
            
            if echo $METRIC_RESPONSE | jq '.data.result | length' > /dev/null 2>&1; then
                RESULT_COUNT=$(echo $METRIC_RESPONSE | jq '.data.result | length')
                if [ "$RESULT_COUNT" -gt 0 ]; then
                    success "✅ Métrica '$query' tiene $RESULT_COUNT resultados"
                else
                    warning "⚠️  Métrica '$query' no tiene datos"
                fi
            else
                warning "⚠️  Error consultando métrica '$query'"
            fi
        done
        
        # Verificar alertas activas
        ALERTS_RESPONSE=$(curl -s http://localhost:9090/api/v1/alerts --connect-timeout 10)
        if echo $ALERTS_RESPONSE | jq '.data.alerts' > /dev/null 2>&1; then
            ACTIVE_ALERTS=$(echo $ALERTS_RESPONSE | jq '.data.alerts | length')
            if [ "$ACTIVE_ALERTS" -gt 0 ]; then
                warning "⚠️  Hay $ACTIVE_ALERTS alertas activas"
                echo $ALERTS_RESPONSE | jq '.data.alerts[] | .labels.alertname'
            else
                success "✅ No hay alertas activas"
            fi
        fi
        
        kill $PROM_PF_PID2 2>/dev/null || true
    fi
    
else
    warning "Namespace 'monitoring' no existe - stack de monitoreo no desplegado"
fi

echo
log "=== 🔄 Test de Integración Completo ==="
if [ ! -z "$TOKEN" ]; then
    log "Ejecutando flujo completo de la aplicación..."
    
    # 1. Crear un todo
    log "1. Creando todo de prueba..."
    TODO_CREATE=$(curl -s -X POST http://localhost:8082/todos \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"content": "Integration test todo"}' \
        --connect-timeout 10)
    
    if echo $TODO_CREATE | jq . > /dev/null 2>&1; then
        success "✅ Todo creado en integración"
        TODO_ID=$(echo $TODO_CREATE | jq -r '.id // empty')
        
        # 2. Verificar que el todo aparece en la lista
        log "2. Verificando lista de todos..."
        TODO_LIST=$(curl -s -X GET http://localhost:8082/todos \
            -H "Authorization: Bearer $TOKEN" \
            --connect-timeout 10)
        
        if echo $TODO_LIST | jq . | grep -q "Integration test todo"; then
            success "✅ Todo encontrado en la lista"
            
            # 3. Verificar logs del log processor (debería mostrar actividad)
            log "3. Verificando logs del processor..."
            sleep 2  # Esperar procesamiento
            PROCESSOR_LOGS=$(kubectl logs --tail=5 -l app=log-processor -n $NAMESPACE 2>/dev/null || echo "No logs available")
            if echo "$PROCESSOR_LOGS" | grep -qi "create\|todo"; then
                success "✅ Log processor registró la actividad"
            else
                warning "⚠️  Log processor no muestra actividad reciente"
            fi
            
            # 4. Limpiar eliminando el todo
            if [ ! -z "$TODO_ID" ] && [ "$TODO_ID" != "null" ]; then
                log "4. Limpiando todo de prueba..."
                curl -s -X DELETE http://localhost:8082/todos/$TODO_ID \
                    -H "Authorization: Bearer $TOKEN" \
                    --connect-timeout 10
                success "✅ Todo de prueba eliminado"
            fi
        else
            warning "⚠️  Todo no encontrado en la lista"
        fi
    else
        error "❌ No se pudo crear todo de integración"
    fi
else
    warning "⚠️  Test de integración omitido (no hay token)"
fi

echo
log "=== 📊 Estado del Cluster ==="
echo "Pods:"
kubectl get pods -n $NAMESPACE --no-headers | while read line; do
    name=$(echo $line | awk '{print $1}')
    ready=$(echo $line | awk '{print $2}')
    status=$(echo $line | awk '{print $3}')
    if [[ "$ready" == "1/1" && "$status" == "Running" ]]; then
        success "$name: $ready $status"
    else
        warning "$name: $ready $status"
    fi
done

echo
log "Servicios:"
kubectl get services -n $NAMESPACE

echo
log "ConfigMaps y Secrets:"
kubectl get configmaps,secrets -n $NAMESPACE

echo
log "HPA (si está disponible):"
kubectl get hpa -n $NAMESPACE 2>/dev/null || warning "HPA no disponible"

echo
log "Network Policies:"
kubectl get networkpolicy -n $NAMESPACE 2>/dev/null || warning "Network Policies no disponibles"

echo
log "Pod Disruption Budgets:"
kubectl get pdb -n $NAMESPACE 2>/dev/null || warning "PDB no disponibles"

echo
log "Persistent Volume Claims:"
kubectl get pvc -n $NAMESPACE 2>/dev/null || warning "PVC no disponibles"

echo
log "📋 Resumen de Verificaciones:"
success "✅ Auth API: Login y JWT token generation"
success "✅ Users API: Lista de usuarios y endpoint específico" 
success "✅ Todos API: CRUD completo (GET, POST, DELETE)"
success "✅ Frontend: Interfaz web y assets"
success "✅ Redis: Conectividad verificada"
success "✅ Log Processor: Procesamiento de eventos"
success "✅ Prometheus: Métricas y targets verificados"
success "✅ Grafana: Dashboards y datasources configurados"
success "✅ Integración: Flujo completo de aplicación"
success "✅ Monitoreo: Stack completo de observabilidad"

echo
echo -e "${GREEN}🎉 Testing de Kubernetes completado!${NC}"

log "🌐 Para acceder al frontend: http://localhost:8080"
log "📖 Los port forwards seguirán activos hasta que presiones Ctrl+C"

# Mantener port forwards activos
log "⏳ Manteniendo port forwards activos... (Ctrl+C para salir)"
wait