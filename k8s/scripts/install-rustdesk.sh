#!/bin/bash
# install-rustdesk.sh - RustDesk Kubernetes 快速安装脚本

set -e

NAMESPACE="${NAMESPACE:-rustdesk}"
RELEASE_NAME="${RELEASE_NAME:-rustdesk}"
METHOD="${METHOD:-helm}"

echo "=========================================="
echo "RustDesk Kubernetes 快速安装"
echo "=========================================="
echo "命名空间: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "安装方式: $METHOD"
echo ""

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "错误: kubectl 未安装"
    exit 1
fi

# 检查 kubectl 连接
if ! kubectl cluster-info &> /dev/null; then
    echo "错误: 无法连接到 Kubernetes 集群"
    exit 1
fi

echo "✓ Kubernetes 集群连接正常"

# 选择安装方式
if [ "$METHOD" == "manifest" ]; then
    echo ""
    echo "使用 Kubernetes Manifest 安装..."

    # 创建命名空间
    echo "创建命名空间..."
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # 部署资源
    echo "部署 ConfigMap..."
    kubectl apply -f k8s/manifests/configmap.yaml -n "$NAMESPACE"

    echo "部署 Secret..."
    kubectl apply -f k8s/manifests/secret.yaml -n "$NAMESPACE"

    echo "部署 PVC..."
    kubectl apply -f k8s/manifests/pvc.yaml -n "$NAMESPACE"

    echo "部署 HBBS..."
    kubectl apply -f k8s/manifests/deployment-hbbs.yaml -n "$NAMESPACE"

    echo "部署 HBBR..."
    kubectl apply -f k8s/manifests/deployment-hbbr.yaml -n "$NAMESPACE"

    echo "部署 Service..."
    kubectl apply -f k8s/manifests/service.yaml -n "$NAMESPACE"

    echo "部署 HPA..."
    kubectl apply -f k8s/manifests/hpa.yaml -n "$NAMESPACE"

    echo "部署 PDB..."
    kubectl apply -f k8s/manifests/pdb.yaml -n "$NAMESPACE"

elif [ "$METHOD" == "helm" ]; then
    # 检查 Helm
    if ! command -v helm &> /dev/null; then
        echo "错误: Helm 未安装"
        exit 1
    fi

    echo ""
    echo "使用 Helm Chart 安装..."

    # 添加 Helm 仓库
    echo "添加 Helm 仓库..."
    helm repo add rustdesk https://rustdesk.github.io/rustdesk 2>/dev/null || true
    helm repo update

    # 检查是否已存在
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        echo "警告: $RELEASE_NAME 已存在，更新中..."
        helm upgrade "$RELEASE_NAME" rustdesk/rustdesk-server \
            -n "$NAMESPACE" \
            --create-namespace
    else
        echo "安装 Helm Chart..."
        helm install "$RELEASE_NAME" rustdesk/rustdesk-server \
            -n "$NAMESPACE" \
            --create-namespace
    fi

else
    echo "错误: 无效的安装方式: $METHOD"
    echo "支持的安装方式: helm, manifest"
    exit 1
fi

# 等待 Pods 就绪
echo ""
echo "等待 Pods 就绪..."
kubectl wait --for=condition=ready pod -n "$NAMESPACE" -l app.kubernetes.io/name=rustdesk --timeout=300s || {
    echo "警告: 等待超时，检查 Pods 状态..."
    kubectl get pods -n "$NAMESPACE"
}

# 显示部署结果
echo ""
echo "=========================================="
echo "安装完成!"
echo "=========================================="
echo ""
echo "命名空间: $NAMESPACE"
kubectl get all -n "$NAMESPACE"
echo ""

# 显示服务信息
echo "服务信息:"
echo "  HBBS Service:"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/component=hbbs
echo "  HBBR Service:"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/component=hbbr
echo ""

# 显示 HPA 信息
if kubectl get hpa -n "$NAMESPACE" &> /dev/null; then
    echo "HPA 状态:"
    kubectl get hpa -n "$NAMESPACE"
    echo ""
fi

# 显示 PVC 信息
if kubectl get pvc -n "$NAMESPACE" &> /dev/null; then
    echo "PVC 状态:"
    kubectl get pvc -n "$NAMESPACE"
    echo ""
fi

echo "=========================================="
echo "下一步操作"
echo "=========================================="
echo ""
echo "1. 查看日志:"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hbbs"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hbbr"
echo ""
echo "2. 配置 RustDesk 客户端:"
echo "   - ID Server: <your-server-ip>:32115"
echo "   - Relay Server: <your-server-ip>:32116"
echo ""
echo "3. 扩展副本数:"
echo "   kubectl scale deployment rustdesk-hbbs -n $NAMESPACE --replicas=3"
echo "   kubectl scale deployment rustdesk-hbbr -n $NAMESPACE --replicas=3"
echo ""
echo "4. 卸载:"
echo "   kubectl delete -f k8s/manifests/ -n $NAMESPACE"
echo "   # 或"
echo "   helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
