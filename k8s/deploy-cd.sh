#!/bin/bash

# Script de Despliegue Automatizado - CI/CD Pipeline
# Microservices K8s Deployment

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
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║        MICROSERVICES K8S DEPLOYMENT              ║"
echo "║             CI/CD Pipeline v1.0                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Variables
NAMESPACE="microservices"
MONITORING_NAMESPACE="monitoring"
MANIFESTS_DIR="./manifests"
COMMAND="${1:-deploy}"
DEPLOYMENT_MODE="${2:-rolling}"  # rolling, blue-green, recreate

log "Iniciando $COMMAND en modo: $DEPLOYMENT_MODE"

# Verificaciones previas
log "🔍 Verificando prerrequisitos..."

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    error "kubectl no está instalado"
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    error "No se puede conectar al cluster de Kubernetes"
fi

success "kubectl configurado correctamente"

# Verificar metrics-server para HPA
log "Verificando Metrics Server para HPA..."
if kubectl get apiservice v1beta1.metrics.k8s.io &> /dev/null; then
    success "Metrics Server disponible"
else
    warning "Metrics Server no disponible - HPA puede no funcionar"
fi

# Función de despliegue
deploy_manifests() {
    local mode=$1
    
    case $mode in
        "rolling")
            log "🚀 Ejecutando Rolling Update Deployment"
            kubectl apply -k $MANIFESTS_DIR
            ;;
        "recreate")
            log "🔄 Ejecutando Recreate Deployment"
            kubectl delete -k $MANIFESTS_DIR --ignore-not-found=true
            sleep 10
            kubectl apply -k $MANIFESTS_DIR
            ;;
        "blue-green")
            log "🔵 Ejecutando Blue-Green Deployment"
            deploy_blue_green
            ;;
        *)
            error "Modo de despliegue no válido: $mode"
            ;;
    esac
}

# Función Blue-Green Deployment
deploy_blue_green() {
    local CURRENT_ENV=$(kubectl get service frontend -n $NAMESPACE -o jsonpath='{.metadata.labels.environment}' 2>/dev/null || echo "blue")
    local TARGET_ENV="green"
    
    if [ "$CURRENT_ENV" = "green" ]; then
        TARGET_ENV="blue"
    fi
    
    log "Ambiente actual: $CURRENT_ENV, desplegando: $TARGET_ENV"
    
    # Crear manifiestos temporales para el nuevo ambiente
    mkdir -p /tmp/k8s-$TARGET_ENV
    cp -r $MANIFESTS_DIR/* /tmp/k8s-$TARGET_ENV/
    
    # Modificar labels y nombres para el nuevo ambiente
    sed -i "s/environment: production/environment: $TARGET_ENV/g" /tmp/k8s-$TARGET_ENV/*.yaml
    sed -i "s/name: frontend/name: frontend-$TARGET_ENV/g" /tmp/k8s-$TARGET_ENV/08-frontend.yaml
    
    # Desplegar nuevo ambiente
    kubectl apply -k /tmp/k8s-$TARGET_ENV/
    
    # Esperar que el nuevo ambiente esté listo
    kubectl wait --for=condition=available --timeout=300s deployment/frontend-$TARGET_ENV -n $NAMESPACE
    
    # Cambiar el tráfico al nuevo ambiente
    kubectl patch service frontend -n $NAMESPACE -p '{"spec":{"selector":{"environment":"'$TARGET_ENV'"}}}'
    
    success "Tráfico cambiado al ambiente $TARGET_ENV"
    
    # Opción de rollback
    read -p "¿Confirmar el cambio? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Realizando rollback..."
        kubectl patch service frontend -n $NAMESPACE -p '{"spec":{"selector":{"environment":"'$CURRENT_ENV'"}}}'
        kubectl delete deployment frontend-$TARGET_ENV -n $NAMESPACE
        warning "Rollback completado"
        return 1
    fi
    
    # Eliminar el ambiente anterior
    if kubectl get deployment frontend-$CURRENT_ENV -n $NAMESPACE &> /dev/null; then
        kubectl delete deployment frontend-$CURRENT_ENV -n $NAMESPACE
    fi
    
    success "Blue-Green deployment completado"
}

# Función de health checks
health_checks() {
    log "🏥 Ejecutando Health Checks..."
    
    local services=("auth-api" "users-api" "todos-api" "frontend" "redis")
    local failed=0
    
    for service in "${services[@]}"; do
        log "Verificando $service..."
        
        # Esperar que el deployment esté listo
        if kubectl wait --for=condition=available --timeout=120s deployment/$service -n $NAMESPACE 2>/dev/null; then
            success "$service está disponible"
        else
            error "$service no está disponible"
            ((failed++))
        fi
        
        # Verificar readiness de pods
        local ready_pods=$(kubectl get pods -n $NAMESPACE -l app=$service -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c "True" || echo "0")
        local total_pods=$(kubectl get pods -n $NAMESPACE -l app=$service --no-headers | wc -l)
        
        if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            success "$service: $ready_pods/$total_pods pods ready"
        else
            warning "$service: $ready_pods/$total_pods pods ready"
        fi
    done
    
    # Verificar HPA
    log "Verificando HPA..."
    kubectl get hpa -n $NAMESPACE --no-headers | while read hpa_line; do
        local hpa_name=$(echo $hpa_line | awk '{print $1}')
        success "HPA $hpa_name configurado"
    done
    
    # Verificar monitoring
    if kubectl get deployment prometheus -n $MONITORING_NAMESPACE &> /dev/null; then
        if kubectl wait --for=condition=available --timeout=60s deployment/prometheus -n $MONITORING_NAMESPACE 2>/dev/null; then
            success "Prometheus está disponible"
        fi
    fi
    
    if kubectl get deployment grafana -n $MONITORING_NAMESPACE &> /dev/null; then
        if kubectl wait --for=condition=available --timeout=60s deployment/grafana -n $MONITORING_NAMESPACE 2>/dev/null; then
            success "Grafana está disponible"
        fi
    fi
    
    return $failed
}

# Función de testing post-deployment
post_deployment_tests() {
    log "🧪 Ejecutando tests post-deployment..."
    
    # Port forward temporal para testing
    kubectl port-forward svc/frontend 8080:8080 -n $NAMESPACE &
    local pf_pid=$!
    
    sleep 5
    
    # Test básico de conectividad
    if curl -f -s http://localhost:8080 > /dev/null; then
        success "Frontend responde correctamente"
    else
        warning "Frontend no responde"
    fi
    
    # Limpiar port forward
    kill $pf_pid 2>/dev/null || true
}

# Función de rollback
rollback() {
    log "🔄 Ejecutando rollback..."
    
    local services=("auth-api" "users-api" "todos-api" "frontend")
    
    for service in "${services[@]}"; do
        if kubectl rollout history deployment/$service -n $NAMESPACE &> /dev/null; then
            kubectl rollout undo deployment/$service -n $NAMESPACE
            log "Rollback aplicado a $service"
        fi
    done
    
    success "Rollback completado"
}

# Función de limpieza
cleanup() {
    log "🗑️  Ejecutando limpieza..."
    kubectl delete -k $MANIFESTS_DIR --ignore-not-found=true
    kubectl delete namespace $MONITORING_NAMESPACE --ignore-not-found=true
    success "Limpieza completada"
}

# Función principal
main() {
    case "$COMMAND" in
        "deploy")
            deploy_manifests $DEPLOYMENT_MODE
            health_checks
            if [ $? -eq 0 ]; then
                post_deployment_tests
                success "🎉 Despliegue completado exitosamente"
                
                # Mostrar información de acceso
                echo -e "\n${YELLOW}📋 Información de Acceso:${NC}"
                echo -e "${GREEN}Frontend:${NC} kubectl port-forward svc/frontend 8080:8080 -n microservices"
                echo -e "${GREEN}Grafana:${NC} kubectl port-forward svc/grafana 3000:3000 -n monitoring"
                echo -e "${GREEN}Prometheus:${NC} kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
            else
                error "Health checks fallaron"
            fi
            ;;
        "rollback")
            rollback
            ;;
        "cleanup")
            cleanup
            ;;
        "test")
            post_deployment_tests
            ;;
        *)
            echo "Uso: $0 {deploy|rollback|cleanup|test} [rolling|blue-green|recreate]"
            echo ""
            echo "Modos de despliegue:"
            echo "  rolling   - Rolling update (default)"
            echo "  blue-green - Blue-Green deployment"
            echo "  recreate  - Recreate all resources"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main