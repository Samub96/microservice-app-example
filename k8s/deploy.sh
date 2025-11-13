#!/bin/bash

# Script para desplegar microservicios en Kubernetes
# Este script despliega toda la aplicación de microservicios con todas las configuraciones

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Desplegando Microservicios en Kubernetes ===${NC}"

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado${NC}"
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: No se puede conectar al cluster de Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Conexión al cluster establecida${NC}"

# Función para esperar que los pods estén ready
wait_for_pods() {
    local namespace=$1
    local app=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}Esperando que los pods de $app estén listos...${NC}"
    kubectl wait --for=condition=ready pod -l app=$app -n $namespace --timeout=${timeout}s
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Pods de $app están listos${NC}"
    else
        echo -e "${RED}✗ Timeout esperando pods de $app${NC}"
        return 1
    fi
}

# Crear namespace
echo -e "${YELLOW}Creando namespace...${NC}"
kubectl apply -f manifests/00-namespace.yaml

# Aplicar ConfigMaps y Secrets
echo -e "${YELLOW}Aplicando ConfigMaps y Secrets...${NC}"
kubectl apply -f manifests/01-configmaps.yaml
kubectl apply -f manifests/02-secrets.yaml

# Desplegar Redis (base de datos)
echo -e "${YELLOW}Desplegando Redis...${NC}"
kubectl apply -f manifests/03-redis.yaml
wait_for_pods "microservices" "redis" 120

# Desplegar Users API
echo -e "${YELLOW}Desplegando Users API...${NC}"
kubectl apply -f manifests/04-users-api.yaml
wait_for_pods "microservices" "users-api" 180

# Desplegar Auth API
echo -e "${YELLOW}Desplegando Auth API...${NC}"
kubectl apply -f manifests/05-auth-api.yaml
wait_for_pods "microservices" "auth-api" 120

# Desplegar Todos API
echo -e "${YELLOW}Desplegando Todos API...${NC}"
kubectl apply -f manifests/06-todos-api.yaml
wait_for_pods "microservices" "todos-api" 120

# Desplegar Log Processor
echo -e "${YELLOW}Desplegando Log Processor...${NC}"
kubectl apply -f manifests/07-log-processor.yaml

# Desplegar Frontend
echo -e "${YELLOW}Desplegando Frontend...${NC}"
kubectl apply -f manifests/08-frontend.yaml
wait_for_pods "microservices" "frontend" 120

# Aplicar HPA
echo -e "${YELLOW}Configurando Horizontal Pod Autoscaler...${NC}"
kubectl apply -f manifests/09-hpa.yaml

# Aplicar Network Policies
echo -e "${YELLOW}Configurando Network Policies...${NC}"
kubectl apply -f manifests/10-network-policies.yaml

# Aplicar Pod Disruption Budgets
echo -e "${YELLOW}Configurando Pod Disruption Budgets...${NC}"
kubectl apply -f manifests/11-pdb.yaml

# Aplicar monitoreo (opcional)
echo -e "${YELLOW}Configurando monitoreo...${NC}"
kubectl apply -f manifests/12-monitoring.yaml || echo -e "${YELLOW}⚠ Monitoreo no aplicado (puede que Prometheus no esté instalado)${NC}"

echo -e "${GREEN}=== Despliegue completado exitosamente ===${NC}"

# Mostrar estado de los pods
echo -e "${BLUE}Estado de los pods:${NC}"
kubectl get pods -n microservices

echo -e "${BLUE}Servicios disponibles:${NC}"
kubectl get services -n microservices

# Obtener URL del frontend
FRONTEND_PORT=$(kubectl get svc frontend -n microservices -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
if [ -n "$FRONTEND_PORT" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo -e "${GREEN}Frontend disponible en: http://$NODE_IP:$FRONTEND_PORT${NC}"
fi

echo -e "${BLUE}Para ver logs de un servicio específico, usar:${NC}"
echo "kubectl logs -f deployment/<service-name> -n microservices"

echo -e "${BLUE}Para escalar un servicio manualmente:${NC}"
echo "kubectl scale deployment <service-name> --replicas=<number> -n microservices"

echo -e "${BLUE}Para ver métricas de HPA:${NC}"
echo "kubectl get hpa -n microservices"