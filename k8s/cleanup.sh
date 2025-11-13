#!/bin/bash

# Script para limpiar/eliminar el despliegue de microservicios

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Eliminando despliegue de Microservicios ===${NC}"

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado${NC}"
    exit 1
fi

echo -e "${YELLOW}Eliminando recursos...${NC}"

# Eliminar en orden inverso
kubectl delete -f manifests/12-monitoring.yaml --ignore-not-found=true
kubectl delete -f manifests/11-pdb.yaml --ignore-not-found=true
kubectl delete -f manifests/10-network-policies.yaml --ignore-not-found=true
kubectl delete -f manifests/09-hpa.yaml --ignore-not-found=true
kubectl delete -f manifests/08-frontend.yaml --ignore-not-found=true
kubectl delete -f manifests/07-log-processor.yaml --ignore-not-found=true
kubectl delete -f manifests/06-todos-api.yaml --ignore-not-found=true
kubectl delete -f manifests/05-auth-api.yaml --ignore-not-found=true
kubectl delete -f manifests/04-users-api.yaml --ignore-not-found=true
kubectl delete -f manifests/03-redis.yaml --ignore-not-found=true
kubectl delete -f manifests/02-secrets.yaml --ignore-not-found=true
kubectl delete -f manifests/01-configmaps.yaml --ignore-not-found=true

# Esperar a que los pods se eliminen
echo -e "${YELLOW}Esperando que los pods se eliminen...${NC}"
kubectl wait --for=delete pods --all -n microservices --timeout=120s || true

# Eliminar namespace
kubectl delete -f manifests/00-namespace.yaml --ignore-not-found=true

echo -e "${GREEN}=== Limpieza completada ===${NC}"

# Verificar que no queden recursos
REMAINING_PODS=$(kubectl get pods -n microservices 2>/dev/null | wc -l || echo "0")
if [ "$REMAINING_PODS" -eq "0" ]; then
    echo -e "${GREEN}✓ Todos los recursos han sido eliminados${NC}"
else
    echo -e "${YELLOW}⚠ Algunos recursos pueden estar aún eliminándose${NC}"
    kubectl get all -n microservices 2>/dev/null || true
fi