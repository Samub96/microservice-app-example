#!/bin/bash

# Script simplificado para testing rápido
# Ejecutar con: bash quick-test.sh

echo "🧪 TESTING MICROSERVICIOS..."

# Test Auth API
echo "=== Auth API ==="
curl -s -X POST http://localhost:8081/login -H "Content-Type: application/json" -d '{"username": "admin", "password": "admin"}' | jq .

# Obtener token
TOKEN=$(curl -s -X POST http://localhost:8081/login -H "Content-Type: application/json" -d '{"username": "admin", "password": "admin"}' | jq -r '.accessToken')

echo -e "\n=== Users API ==="
curl -s -X GET http://localhost:8083/users/ -H "Authorization: Bearer $TOKEN" | jq .

echo -e "\n=== Todos API ==="
curl -s -X GET http://localhost:8082/todos -H "Authorization: Bearer $TOKEN" | jq .

echo -e "\n=== Frontend ==="
curl -s http://localhost:8080 | grep -i title

echo -e "\n=== Redis ==="
docker exec redis redis-cli ping

echo -e "\n=== Docker Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n✅ Testing completo!"