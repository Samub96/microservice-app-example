#!/bin/bash

# Script para reducir réplicas en entorno de desarrollo
echo "🔧 Reduciendo réplicas para entorno de desarrollo..."

# Reducir HPA mínimos temporalmente
kubectl patch hpa auth-api-hpa -n microservices -p '{"spec":{"minReplicas":1}}'
kubectl patch hpa users-api-hpa -n microservices -p '{"spec":{"minReplicas":1}}'
kubectl patch hpa todos-api-hpa -n microservices -p '{"spec":{"minReplicas":1}}'
kubectl patch hpa frontend-hpa -n microservices -p '{"spec":{"minReplicas":1}}'

echo "✅ Réplicas mínimas reducidas a 1 para desarrollo"
echo "⏳ Los pods se reducirán automáticamente en unos minutos"

# Ver estado
echo ""
echo "Estado actual:"
kubectl get hpa -n microservices