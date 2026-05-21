#!/bin/bash

set -e

echo "开始部署 RustDesk 监控栈到 Kubernetes..."

NAMESPACE="monitoring"

echo "1. 创建命名空间..."
kubectl apply -f namespace.yaml

echo "2. 部署 Prometheus..."
kubectl apply -f prometheus.yaml

echo "3. 部署 Grafana..."
kubectl apply -f grafana.yaml

echo "4. 部署 AlertManager 和 Node Exporter..."
kubectl apply -f alertmanager.yaml

echo "5. 等待 Pod 就绪..."
kubectl rollout status deployment/prometheus -n $NAMESPACE
kubectl rollout status deployment/grafana -n $NAMESPACE
kubectl rollout status deployment/alertmanager -n $NAMESPACE
kubectl rollout status deployment/node-exporter -n $NAMESPACE

echo "6. 检查服务状态..."
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE

echo ""
echo "监控栈部署完成！"
echo ""
echo "访问地址："
echo "- Prometheus: kubectl port-forward -n $NAMESPACE svc/prometheus-service 9090:9090"
echo "- Grafana: kubectl port-forward -n $NAMESPACE svc/grafana-service 3000:3000"
echo "- AlertManager: kubectl port-forward -n $NAMESPACE svc/alertmanager-service 9093:9093"
echo ""
echo "Grafana 默认凭据："
echo "- 用户名: admin"
echo "- 密码: admin123"
