#!/bin/bash

# Script para acceder a Prometheus y Grafana
# Ejecutar con: bash monitoring-access.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Banner
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║           PROMETHEUS & GRAFANA ACCESS            ║"
echo "║                  v1.0                           ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

NAMESPACE="monitoring"

log "🔍 Verificando estado de Prometheus y Grafana..."

# Verificar pods
echo "Estado de los pods de monitoring:"
kubectl get pods -n $NAMESPACE

echo

# Verificar servicios
log "📋 Servicios disponibles:"
kubectl get services -n $NAMESPACE

echo

# Función para limpiar port forwards al salir
cleanup() {
    log "🧹 Limpiando port forwards..."
    pkill -f "kubectl port-forward.*monitoring" || true
    wait
    log "✅ Limpieza completada"
}
trap cleanup EXIT

# Verificar qué servicios de Prometheus y Grafana están disponibles
PROMETHEUS_SERVICES=$(kubectl get services -n $NAMESPACE -o name | grep prometheus | head -1)
GRAFANA_SERVICES=$(kubectl get services -n $NAMESPACE -o name | grep grafana)

log "🚀 Configurando accesos..."

if [ ! -z "$PROMETHEUS_SERVICES" ]; then
    PROMETHEUS_SERVICE=$(echo $PROMETHEUS_SERVICES | sed 's|service/||')
    log "📊 Configurando acceso a Prometheus (servicio: $PROMETHEUS_SERVICE)"
    
    # Port forward para Prometheus en background
    kubectl port-forward svc/$PROMETHEUS_SERVICE 9090:9090 -n $NAMESPACE &
    PROMETHEUS_PF_PID=$!
    
    success "Prometheus estará disponible en: http://localhost:9090"
    info "Targets: http://localhost:9090/targets"
    info "Métricas: http://localhost:9090/graph"
else
    error "No se encontró servicio de Prometheus"
fi

echo

if [ ! -z "$GRAFANA_SERVICES" ]; then
    # Usar prometheus-grafana si está disponible, si no usar grafana
    if echo "$GRAFANA_SERVICES" | grep -q "prometheus-grafana"; then
        GRAFANA_SERVICE="prometheus-grafana"
        GRAFANA_PORT="80"
    else
        GRAFANA_SERVICE="grafana"
        GRAFANA_PORT="3000"
    fi
    
    log "📈 Configurando acceso a Grafana (servicio: $GRAFANA_SERVICE)"
    
    # Port forward para Grafana en background
    kubectl port-forward svc/$GRAFANA_SERVICE 3000:$GRAFANA_PORT -n $NAMESPACE &
    GRAFANA_PF_PID=$!
    
    success "Grafana estará disponible en: http://localhost:3000"
    info "Usuario: admin"
    
    # Intentar obtener password de Grafana
    GRAFANA_PASSWORD=$(kubectl get secret --namespace $NAMESPACE prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "")
    
    if [ ! -z "$GRAFANA_PASSWORD" ]; then
        info "Password: $GRAFANA_PASSWORD"
    else
        info "Password: admin123 (o revisar secrets)"
        warning "Si no puedes acceder, revisa: kubectl get secrets -n monitoring"
    fi
else
    error "No se encontró servicio de Grafana"
fi

echo

# Esperar a que los port forwards estén listos
log "⏳ Esperando a que los port forwards estén listos..."
sleep 5

# Verificar conectividad
log "🧪 Verificando conectividad..."

if [ ! -z "$PROMETHEUS_SERVICES" ]; then
    if curl -s --connect-timeout 5 http://localhost:9090/-/healthy > /dev/null 2>&1; then
        success "✅ Prometheus respondiendo correctamente"
    else
        warning "⚠️  Prometheus puede tardar en estar listo"
    fi
fi

if [ ! -z "$GRAFANA_SERVICES" ]; then
    if curl -s --connect-timeout 5 http://localhost:3000/api/health > /dev/null 2>&1; then
        success "✅ Grafana respondiendo correctamente"
    else
        warning "⚠️  Grafana puede tardar en estar listo"
    fi
fi

echo
echo -e "${GREEN}🎉 Configuración completa!${NC}"
echo
echo -e "${CYAN}📊 PROMETHEUS:${NC}"
echo "   🌐 URL: http://localhost:9090"
echo "   🎯 Targets: http://localhost:9090/targets"
echo "   📈 Métricas: http://localhost:9090/graph"
echo
echo -e "${CYAN}📈 GRAFANA:${NC}"
echo "   🌐 URL: http://localhost:3000"
echo "   👤 Usuario: admin"
echo "   🔑 Password: ${GRAFANA_PASSWORD:-admin123}"
echo
echo -e "${CYAN}💡 TIPS:${NC}"
echo "   • En Grafana, los datasources ya están configurados automáticamente"
echo "   • Prometheus estará disponible como datasource en Grafana"
echo "   • Puedes importar dashboards desde https://grafana.com/grafana/dashboards/"
echo "   • Dashboard recomendado para Kubernetes: 315 (Kubernetes cluster monitoring)"
echo
log "⏳ Port forwards activos... (Ctrl+C para salir)"

# Mantener port forwards activos
wait