#!/bin/bash

# Script de despliegue rápido para microservices-app
# Uso: ./quick-deploy.sh [local|production] [registry-name]

set -e

MODE=${1:-local}
REGISTRY=${2:-""}

echo "🚀 Iniciando despliegue en modo: $MODE"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_step() {
    echo -e "\n${BLUE}📋 $1${NC}"
}

function print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar herramientas necesarias
print_step "Verificando herramientas..."
command -v docker >/dev/null 2>&1 || { print_error "Docker no encontrado. Instálalo primero."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl no encontrado. Instálalo primero."; exit 1; }

if [ "$MODE" = "local" ]; then
    command -v kind >/dev/null 2>&1 || { print_warning "kind no encontrado. Asegúrate de tener un cluster local."; }
fi

print_success "Herramientas verificadas"

# Función para construir imágenes
build_images() {
    print_step "Construyendo imágenes Docker..."
    
    local tag_suffix=""
    if [ "$MODE" = "production" ] && [ -n "$REGISTRY" ]; then
        tag_suffix="$REGISTRY/"
    fi

    docker build -f dockerfiles/dockerfile.authApi -t "${tag_suffix}auth-api:latest" ./auth-api
    docker build -f dockerfiles/dockerfile.userApi -t "${tag_suffix}users-api:latest" ./users-api  
    docker build -f dockerfiles/dockerfile.todoApi -t "${tag_suffix}todos-api:latest" ./todos-api
    docker build -f dockerfiles/dockerfile.frontend -t "${tag_suffix}frontend:latest" ./frontend
    docker build -f dockerfiles/dockerfile.log-message -t "${tag_suffix}log-processor:latest" ./log-message-processor
    
    print_success "Imágenes construidas"
}

# Función para cargar imágenes en kind
load_images_kind() {
    print_step "Cargando imágenes en kind..."
    
    # Verificar si el cluster kind existe
    if ! kind get clusters | grep -q "microservices"; then
        print_step "Creando cluster kind..."
        kind create cluster --name microservices
    fi
    
    # Cargar imágenes
    kind load docker-image auth-api:latest --name microservices
    kind load docker-image users-api:latest --name microservices
    kind load docker-image todos-api:latest --name microservices
    kind load docker-image frontend:latest --name microservices
    kind load docker-image log-processor:latest --name microservices
    
    print_success "Imágenes cargadas en kind"
}

# Función para pushear imágenes
push_images() {
    if [ -z "$REGISTRY" ]; then
        print_error "Registry no especificado para modo production"
        echo "Uso: ./quick-deploy.sh production your-dockerhub-username"
        exit 1
    fi
    
    print_step "Pusheando imágenes a $REGISTRY..."
    
    docker push "$REGISTRY/auth-api:latest"
    docker push "$REGISTRY/users-api:latest"
    docker push "$REGISTRY/todos-api:latest"
    docker push "$REGISTRY/frontend:latest"
    docker push "$REGISTRY/log-processor:latest"
    
    print_success "Imágenes pusheadas"
}

# Función para instalar ingress
install_ingress() {
    print_step "Verificando Ingress Controller..."
    
    if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
        print_success "Ingress Controller ya instalado"
        return
    fi
    
    if [ "$MODE" = "local" ]; then
        print_step "Instalando nginx-ingress para kind..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    else
        print_step "Instalando nginx-ingress genérico..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
    fi
    
    print_step "Esperando a que Ingress Controller esté listo..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    print_success "Ingress Controller instalado"
}

# Función para instalar metrics server
install_metrics_server() {
    print_step "Verificando Metrics Server..."
    
    if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
        print_success "Metrics Server ya instalado"
        return
    fi
    
    print_step "Instalando Metrics Server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    # Para desarrollo local, permitir certificados inseguros
    if [ "$MODE" = "local" ]; then
        kubectl patch deployment metrics-server -n kube-system --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
    fi
    
    print_success "Metrics Server instalado"
}

# Función para crear secretos seguros
create_production_secrets() {
    if [ "$MODE" != "production" ]; then
        return
    fi
    
    print_step "Configurando secretos para producción..."
    print_warning "Los secretos de desarrollo están en el archivo 02-secrets.yaml"
    print_warning "Para producción, crea secretos manualmente:"
    
    echo ""
    echo "kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -"
    echo "kubectl -n microservices create secret generic app-secrets \\"
    echo "  --from-literal=JWT_SECRET='tu-jwt-secreto-produccion' \\"
    echo "  --from-literal=DB_PASSWORD='tu-password-db-produccion' \\"
    echo "  --from-literal=REDIS_PASSWORD='tu-password-redis-produccion'"
    echo ""
    
    read -p "¿Has creado los secretos de producción manualmente? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Usando secretos de desarrollo (NO recomendado para producción)"
    fi
}

# Función para aplicar manifests
apply_manifests() {
    print_step "Aplicando manifests de Kubernetes..."
    
    kubectl apply -k k8s/manifests/
    
    print_success "Manifests aplicados"
}

# Función para verificar despliegue
verify_deployment() {
    print_step "Verificando despliegue..."
    
    # Esperar a que los pods estén listos
    print_step "Esperando a que los pods estén listos..."
    kubectl -n microservices wait --for=condition=ready pod --selector=app=users-api --timeout=300s
    kubectl -n microservices wait --for=condition=ready pod --selector=app=auth-api --timeout=300s
    kubectl -n microservices wait --for=condition=ready pod --selector=app=todos-api --timeout=300s
    kubectl -n microservices wait --for=condition=ready pod --selector=app=frontend --timeout=300s
    kubectl -n microservices wait --for=condition=ready pod --selector=app=redis --timeout=300s
    
    # Mostrar estado
    echo ""
    print_success "Estado del despliegue:"
    kubectl -n microservices get pods
    echo ""
    kubectl -n microservices get services
    echo ""
    kubectl -n microservices get ingress
    
    print_success "Despliegue completado"
}

# Función para configurar acceso local
configure_local_access() {
    if [ "$MODE" != "local" ]; then
        return
    fi
    
    print_step "Configurando acceso local..."
    
    # Obtener IP del ingress
    if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
        INGRESS_IP=$(minikube ip)
        print_success "Usando minikube IP: $INGRESS_IP"
    else
        # Para kind, necesitamos port-forward o configurar con Docker
        print_warning "Para kind, configura port-forward o usa Docker network"
        echo "kubectl -n microservices port-forward service/frontend 8080:8080"
        return
    fi
    
    # Verificar si la entrada ya existe en /etc/hosts
    if grep -q "microservices.local" /etc/hosts; then
        print_warning "microservices.local ya existe en /etc/hosts"
    else
        echo "$INGRESS_IP microservices.local" | sudo tee -a /etc/hosts
        print_success "Agregado microservices.local a /etc/hosts"
    fi
    
    print_success "Aplicación disponible en: http://microservices.local"
}

# Script principal
case "$MODE" in
    local)
        print_step "🏠 Modo desarrollo local"
        build_images
        load_images_kind
        install_ingress
        install_metrics_server
        apply_manifests
        verify_deployment
        configure_local_access
        ;;
    production)
        print_step "🏭 Modo producción"
        build_images
        push_images
        create_production_secrets
        install_metrics_server
        apply_manifests
        verify_deployment
        ;;
    *)
        print_error "Modo inválido: $MODE"
        echo "Uso: $0 [local|production] [registry-name]"
        exit 1
        ;;
esac

echo ""
print_success "🎉 Despliegue completado exitosamente!"

# Comandos útiles
echo ""
echo -e "${BLUE}📝 Comandos útiles:${NC}"
echo "  kubectl -n microservices get all"
echo "  kubectl -n microservices logs -f deployment/frontend"
echo "  kubectl -n microservices get hpa"
echo "  kubectl -n microservices port-forward service/frontend 8080:8080"

if [ "$MODE" = "production" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Para monitorización, accede a:${NC}"
    echo "  Grafana: kubectl -n monitoring port-forward service/grafana 3000:3000"
    echo "  Prometheus: kubectl -n monitoring port-forward service/prometheus 9090:9090"
fi