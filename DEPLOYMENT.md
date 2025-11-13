# Guía de Despliegue - Microservices App

Este documento proporciona instrucciones para desplegar la aplicación de microservicios en Kubernetes.

## Arquitectura

- **Frontend** (Vue.js): Puerto 8080
- **Auth API** (Go): Puerto 8081
- **Users API** (Java/Spring): Puerto 8083  
- **Todos API** (Node.js): Puerto 8082
- **Log Processor** (Python): Worker background
- **Redis**: Base de datos en memoria (puerto 6379)

## Pre-requisitos

- Kubernetes cluster (minikube, kind, GKE, EKS, AKS)
- kubectl configurado
- Docker para construir imágenes
- Ingress Controller (nginx-ingress recomendado)
- Metrics Server (para HPA)

## Opción 1: Despliegue Local (kind/minikube)

### Paso 1: Crear cluster (si usas kind)
```bash
kind create cluster --name microservices
kubectl cluster-info --context kind-microservices
```

### Paso 2: Construir y cargar imágenes
```bash
# Navega al directorio raíz del proyecto
cd /workspaces/microservice-app-example

# Construir todas las imágenes
docker build -f dockerfiles/dockerfile.authApi -t auth-api:latest ./auth-api
docker build -f dockerfiles/dockerfile.userApi -t users-api:latest ./users-api  
docker build -f dockerfiles/dockerfile.todoApi -t todos-api:latest ./todos-api
docker build -f dockerfiles/dockerfile.frontend -t frontend:latest ./frontend
docker build -f dockerfiles/dockerfile.log-message -t log-processor:latest ./log-message-processor

# Cargar imágenes en kind (omitir si usas minikube)
kind load docker-image auth-api:latest --name microservices
kind load docker-image users-api:latest --name microservices
kind load docker-image todos-api:latest --name microservices
kind load docker-image frontend:latest --name microservices
kind load docker-image log-processor:latest --name microservices
```

### Paso 3: Instalar Ingress Controller (nginx)
```bash
# Para kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Para minikube
minikube addons enable ingress

# Esperar a que el controlador esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Paso 4: Desplegar aplicación
```bash
# Aplicar todos los manifests usando Kustomize
kubectl apply -k k8s/manifests/

# Verificar el despliegue
kubectl -n microservices get all
kubectl -n microservices get configmap,secret
kubectl -n microservices get ingress
```

### Paso 5: Configurar acceso local
```bash
# Para kind - obtener IP del ingress
INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Para minikube
INGRESS_IP=$(minikube ip)

# Añadir entrada al archivo hosts
echo "$INGRESS_IP microservices.local" | sudo tee -a /etc/hosts

# Acceder a la aplicación
echo "Aplicación disponible en: http://microservices.local"
```

## Opción 2: Despliegue en Producción

### Paso 1: Construir y pushear imágenes
```bash
# Configurar registro (ejemplo con Docker Hub)
REGISTRY="your-dockerhub-username"  # Cambiar por tu usuario

# Construir y taggear
docker build -f dockerfiles/dockerfile.authApi -t $REGISTRY/auth-api:v1.0.0 ./auth-api
docker build -f dockerfiles/dockerfile.userApi -t $REGISTRY/users-api:v1.0.0 ./users-api
docker build -f dockerfiles/dockerfile.todoApi -t $REGISTRY/todos-api:v1.0.0 ./todos-api
docker build -f dockerfiles/dockerfile.frontend -t $REGISTRY/frontend:v1.0.0 ./frontend
docker build -f dockerfiles/dockerfile.log-message -t $REGISTRY/log-processor:v1.0.0 ./log-message-processor

# Pushear al registry
docker push $REGISTRY/auth-api:v1.0.0
docker push $REGISTRY/users-api:v1.0.0
docker push $REGISTRY/todos-api:v1.0.0
docker push $REGISTRY/frontend:v1.0.0
docker push $REGISTRY/log-processor:v1.0.0
```

### Paso 2: Actualizar kustomization con registry
```bash
# Editar k8s/manifests/kustomization.yaml y descomentar/actualizar las líneas newName:
# newName: your-dockerhub-username/auth-api
# newName: your-dockerhub-username/users-api
# etc.
```

### Paso 3: Gestionar secretos de forma segura
```bash
# NO usar los secretos del archivo 02-secrets.yaml en producción
# Crear secretos desde CLI:
kubectl create namespace microservices
kubectl -n microservices create secret generic app-secrets \
  --from-literal=JWT_SECRET='your-production-jwt-secret-here' \
  --from-literal=DB_PASSWORD='your-production-db-password' \
  --from-literal=REDIS_PASSWORD='your-production-redis-password'
```

### Paso 4: Desplegar
```bash
# Aplicar manifests (excluyendo 02-secrets.yaml si usas secretos externos)
kubectl apply -k k8s/manifests/
```

## Comandos de Verificación

### Comprobar estado de pods y servicios
```bash
kubectl -n microservices get pods
kubectl -n microservices get services
kubectl -n microservices get ingress
```

### Ver logs
```bash
kubectl -n microservices logs -f deployment/frontend
kubectl -n microservices logs -f deployment/auth-api
kubectl -n microservices logs -f deployment/users-api
kubectl -n microservices logs -f deployment/todos-api
kubectl -n microservices logs -f deployment/log-processor
```

### Verificar HPA (requiere Metrics Server)
```bash
kubectl -n microservices get hpa
kubectl top nodes
kubectl -n microservices top pods
```

### Port-forward para debugging (alternativo al ingress)
```bash
kubectl -n microservices port-forward service/frontend 8080:8080
# Acceder en http://localhost:8080
```

## Troubleshooting

### Pods en estado Pending
- Verificar recursos disponibles: `kubectl describe nodes`
- Comprobar PVC: `kubectl -n microservices get pvc`

### Imágenes no encontradas (ImagePullBackOff)
- Verificar que las imágenes existen en el registry
- Comprobar credenciales: `kubectl -n microservices get secrets`
- Para desarrollo local, asegurar que `imagePullPolicy: IfNotPresent`

### HPA no funciona
- Instalar Metrics Server: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`
- Verificar: `kubectl get apiservice v1beta1.metrics.k8s.io -o yaml`

### Ingress no accesible
- Verificar Ingress Controller: `kubectl -n ingress-nginx get pods`
- Comprobar configuración DNS/hosts
- Verificar reglas: `kubectl -n microservices describe ingress frontend-ingress`

## Componentes Incluidos

- ✅ **Deployments**: Con probes de salud, recursos y lifecycle hooks
- ✅ **Services**: ClusterIP para APIs, LoadBalancer para frontend
- ✅ **ConfigMaps**: Configuración centralizada de aplicación y Redis
- ✅ **Secrets**: JWT, passwords de DB y Redis
- ✅ **Ingress**: Ruteo HTTP con nginx
- ✅ **HPA**: Autoescalado basado en CPU/memoria
- ✅ **PVC**: Almacenamiento persistente para Redis
- ✅ **Network Policies**: Seguridad de red entre pods
- ✅ **Pod Disruption Budgets**: Alta disponibilidad durante actualizaciones
- ✅ **Monitoring**: Configuración para observabilidad

## Limpieza

```bash
# Eliminar aplicación
kubectl delete -k k8s/manifests/

# Eliminar cluster kind (si aplica)
kind delete cluster --name microservices
```