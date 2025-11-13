# Despliegue de Microservicios en Kubernetes

Esta guía te ayudará a desplegar la aplicación de microservicios completa en Kubernetes con todas las mejores prácticas implementadas.

## 🏗️ Arquitectura

La aplicación consiste en los siguientes servicios:

- **Frontend**: Interfaz web (Vue.js) - Puerto 8080
- **Auth API**: Servicio de autenticación (Go) - Puerto 8081
- **Users API**: Gestión de usuarios (Spring Boot) - Puerto 8083
- **Todos API**: Gestión de tareas (Node.js) - Puerto 8082
- **Log Processor**: Procesamiento de logs (Python)
- **Redis**: Base de datos en memoria

## 📋 Prerrequisitos

1. **Cluster de Kubernetes** funcionando (minikube, EKS, GKE, AKS, etc.)
2. **kubectl** configurado para conectar al cluster
3. **Metrics Server** instalado para HPA (opcional)
4. **Prometheus Operator** para monitoreo (opcional)

### Verificar prerrequisitos:

```bash
# Verificar kubectl
kubectl version --client

# Verificar conexión al cluster
kubectl cluster-info

# Verificar metrics server (para HPA)
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# Verificar nodos
kubectl get nodes
```

## 🚀 Despliegue Rápido

### Opción 1: Script automatizado (Recomendado)

```bash
# Ir al directorio k8s
cd k8s

# Ejecutar el script de despliegue
./deploy.sh
```

### Opción 2: Despliegue manual

```bash
# Aplicar manifiestos en orden
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-configmaps.yaml
kubectl apply -f manifests/02-secrets.yaml
kubectl apply -f manifests/03-redis.yaml
kubectl apply -f manifests/04-users-api.yaml
kubectl apply -f manifests/05-auth-api.yaml
kubectl apply -f manifests/06-todos-api.yaml
kubectl apply -f manifests/07-log-processor.yaml
kubectl apply -f manifests/08-frontend.yaml
kubectl apply -f manifests/09-hpa.yaml
kubectl apply -f manifests/10-network-policies.yaml
kubectl apply -f manifests/11-pdb.yaml
kubectl apply -f manifests/12-monitoring.yaml
```

### Opción 3: Usando Kustomize

```bash
# Desde el directorio manifests
kubectl apply -k manifests/
```

## 🔧 Configuración Implementada

### ConfigMaps
- **app-config**: Configuraciones de aplicación para todos los servicios
- **redis-config**: Configuración específica de Redis

### Secrets
- **app-secrets**: Secretos como JWT_SECRET, passwords
- **registry-secret**: Credenciales para registry de Docker (opcional)

### Horizontal Pod Autoscaler (HPA)
- **CPU**: Escala cuando el uso promedio supera el 70%
- **Memoria**: Escala cuando el uso promedio supera el 80%
- **Rangos de réplicas**:
  - Frontend: 2-6 réplicas
  - Auth API: 2-10 réplicas
  - Users API: 2-8 réplicas
  - Todos API: 2-12 réplicas

### Network Policies
- **Principio de menor privilegio**: Denegación por defecto
- **Comunicación específica**: Solo se permite tráfico necesario
- **Separación de capas**: Frontend → APIs → Base de datos

### Pod Disruption Budgets (PDB)
- Garantiza al menos 1 pod disponible durante actualizaciones
- Protege contra interrupciones involuntarias

### Recursos y Límites
- **Requests**: Recursos mínimos garantizados
- **Limits**: Recursos máximos permitidos
- **Optimizado** para cada tipo de servicio

### Health Checks
- **Liveness Probes**: Detecta contenedores no saludables
- **Readiness Probes**: Controla tráfico hacia pods listos
- **Startup Probes**: Para aplicaciones con inicialización lenta

### Almacenamiento Persistente
- **Redis PVC**: 1GB de almacenamiento para persistencia de datos

## 🔍 Verificación del Despliegue

```bash
# Ver todos los pods
kubectl get pods -n microservices

# Ver servicios
kubectl get services -n microservices

# Ver estado de HPA
kubectl get hpa -n microservices

# Ver métricas de recursos
kubectl top pods -n microservices

# Ver eventos
kubectl get events -n microservices --sort-by='.lastTimestamp'
```

## 🌐 Acceso a la Aplicación

### Desarrollo/Testing:
```bash
# Port forwarding para acceder localmente
kubectl port-forward svc/frontend 8080:8080 -n microservices
# Acceder en: http://localhost:8080
```

### Producción:
- **LoadBalancer**: Si tu cluster soporta LoadBalancer
- **NodePort**: Acceso directo por puerto de nodo
- **Ingress**: Con controlador Nginx (configurado en el frontend)

```bash
# Obtener IP del LoadBalancer
kubectl get svc frontend -n microservices

# Para Ingress, agregar a /etc/hosts:
# <INGRESS_IP> microservices.local
```

## 📊 Monitoreo y Observabilidad

### Logs
```bash
# Ver logs de un servicio específico
kubectl logs -f deployment/frontend -n microservices

# Ver logs de todos los pods de un servicio
kubectl logs -f -l app=auth-api -n microservices
```

### Métricas (si Prometheus está disponible)
- Métricas expuestas en `/metrics` o `/actuator/prometheus`
- ServiceMonitors configurados para scraping automático

### Dashboards recomendados:
- Grafana con dashboards de Kubernetes
- Métricas de aplicación personalizadas
- Alertas basadas en SLOs

## 🔧 Mantenimiento

### Escalado Manual
```bash
# Escalar un servicio específico
kubectl scale deployment frontend --replicas=5 -n microservices
```

### Actualización de Imágenes
```bash
# Actualizar imagen de un deployment
kubectl set image deployment/frontend frontend=frontend:v2.0.0 -n microservices
```

### Rollback
```bash
# Ver historial de rollouts
kubectl rollout history deployment/frontend -n microservices

# Hacer rollback
kubectl rollout undo deployment/frontend -n microservices
```

## 🗑️ Limpieza

```bash
# Usar el script de limpieza
./cleanup.sh

# O eliminar el namespace completo
kubectl delete namespace microservices
```

## 🔐 Seguridad

### Network Policies
- Tráfico entre pods controlado estrictamente
- DNS permitido para resolución de nombres
- Solo puertos necesarios abiertos

### Secrets Management
- Secrets almacenados como objetos de Kubernetes
- Montados como variables de entorno
- Rotación manual requerida

### RBAC (Recomendación futura)
```yaml
# Crear ServiceAccount específico
apiVersion: v1
kind: ServiceAccount
metadata:
  name: microservices-sa
  namespace: microservices
```

## 🚨 Troubleshooting

### Problemas Comunes:

1. **Pods en estado Pending**:
   ```bash
   kubectl describe pod <pod-name> -n microservices
   # Revisar events para problemas de recursos
   ```

2. **HPA no funciona**:
   ```bash
   kubectl describe hpa <hpa-name> -n microservices
   # Verificar que metrics-server está funcionando
   kubectl get apiservice v1beta1.metrics.k8s.io
   ```

3. **Network Policy bloqueando tráfico**:
   ```bash
   # Temporalmente deshabilitar para testing
   kubectl delete networkpolicy --all -n microservices
   ```

4. **Problemas de conectividad**:
   ```bash
   # Test de conectividad desde un pod
   kubectl run test-pod --image=busybox -it --rm -- /bin/sh
   nslookup auth-api.microservices.svc.cluster.local
   ```

## 📝 Notas Adicionales

- **Imágenes**: Actualizar las referencias de imagen según tu registry
- **Secrets**: Cambiar valores por defecto en producción
- **Storage Class**: Ajustar según tu proveedor de cloud
- **Resource Limits**: Ajustar según el tamaño de tu cluster
- **Network Policies**: Personalizar según requisitos de seguridad

## 🤝 Contribución

Para modificar la configuración:
1. Editar los manifiestos en `manifests/`
2. Probar con `kubectl apply --dry-run=client`
3. Aplicar cambios incrementalmente
4. Verificar que todo funciona correctamente

---

**¡Tu aplicación de microservicios está lista para producción en Kubernetes! 🎉**