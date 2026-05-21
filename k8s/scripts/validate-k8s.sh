#!/bin/bash
# validate-k8s.sh - Kubernetes 部署验证脚本

set -e

NAMESPACE="${NAMESPACE:-rustdesk}"
TIMEOUT=300
INTERVAL=5

echo "=========================================="
echo "RustDesk Kubernetes 部署验证脚本"
echo "=========================================="
echo "命名空间: $NAMESPACE"
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: kubectl 未安装${NC}"
    exit 1
fi

# 检查 Helm (可选)
HELM_INSTALLED=false
if command -v helm &> /dev/null; then
    HELM_INSTALLED=true
fi

echo "1. 检查命名空间..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${GREEN}✓ 命名空间 $NAMESPACE 存在${NC}"
else
    echo -e "${RED}✗ 命名空间 $NAMESPACE 不存在${NC}"
    exit 1
fi

echo ""
echo "2. 检查 Deployments..."
for component in hbbs hbbr; do
    echo -n "  检查 $component... "
    if kubectl get deployment "rustdesk-$component" -n "$NAMESPACE" &> /dev/null; then
        replicas=$(kubectl get deployment "rustdesk-$component" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
        desired=$(kubectl get deployment "rustdesk-$component" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
        if [ "$replicas" == "$desired" ]; then
            echo -e "${GREEN}✓ 运行中 ($replicas/$desired 副本)${NC}"
        else
            echo -e "${YELLOW}⚠ 部分运行 ($replicas/$desired 副本)${NC}"
        fi
    else
        echo -e "${RED}✗ 未找到${NC}"
    fi
done

echo ""
echo "3. 检查 Pods..."
pods_not_ready=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=rustdesk --no-headers 2>/dev/null | grep -v Running | grep -v Completed || true)
if [ -z "$pods_not_ready" ]; then
    running_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=rustdesk --no-headers 2>/dev/null | grep -c Running || echo "0")
    echo -e "${GREEN}✓ 所有 Pods 运行正常 ($running_pods 运行中)${NC}"
else
    echo -e "${YELLOW}⚠ 部分 Pods 未运行:${NC}"
    echo "$pods_not_ready"
fi

echo ""
echo "4. 检查 Services..."
for component in hbbs hbbr; do
    echo -n "  检查 $component service... "
    if kubectl get service "rustdesk-$component-service" -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✓ 存在${NC}"
    else
        echo -e "${YELLOW}⚠ 未找到 (可能使用其他命名方式)${NC}"
    fi
done

echo ""
echo "5. 检查 Services 端点..."
for component in hbbs hbbr; do
    echo -n "  检查 $component endpoints... "
    endpoints=$(kubectl get endpoints "rustdesk-$component-service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    if [ -n "$endpoints" ]; then
        count=$(echo $endpoints | wc -w)
        echo -e "${GREEN}✓ $count 个端点${NC}"
    else
        echo -e "${RED}✗ 无端点${NC}"
    fi
done

echo ""
echo "6. 检查 PVC..."
pvc_count=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$pvc_count" -gt 0 ]; then
    echo "  发现 $pvc_count 个 PVC:"
    kubectl get pvc -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,STORAGECLASS:.spec.storageClassName,SIZE:.spec.resources.requests.storage 2>/dev/null | grep -v NAME
    bound_count=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -o Bound | wc -l)
    if [ "$bound_count" -eq "$pvc_count" ]; then
        echo -e "  ${GREEN}✓ 所有 PVC 已绑定${NC}"
    else
        echo -e "  ${YELLOW}⚠ 部分 PVC 未绑定${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 未配置 PVC${NC}"
fi

echo ""
echo "7. 检查 HPA..."
if kubectl get hpa -n "$NAMESPACE" &> /dev/null; then
    echo -e "${GREEN}✓ HPA 已配置${NC}"
    kubectl get hpa -n "$NAMESPACE" -o wide 2>/dev/null
else
    echo -e "${YELLOW}⚠ HPA 未配置${NC}"
fi

echo ""
echo "8. 检查 PodDisruptionBudget..."
if kubectl get pdb -n "$NAMESPACE" &> /dev/null; then
    echo -e "${GREEN}✓ PDB 已配置${NC}"
    kubectl get pdb -n "$NAMESPACE" 2>/dev/null
else
    echo -e "${YELLOW}⚠ PDB 未配置${NC}"
fi

echo ""
echo "9. 测试服务连接..."
echo "  (跳过实际连接测试，使用端口转发验证)"

echo ""
echo "10. 检查资源使用..."
echo "  HBBS Pods:"
kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/component=hbbs 2>/dev/null || echo "  metrics-server 不可用"
echo "  HBBR Pods:"
kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/component=hbbr 2>/dev/null || echo "  metrics-server 不可用"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 配置 RustDesk 客户端连接到此服务器"
echo "  2. 查看日志: kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hbbs"
echo "  3. 扩展副本: kubectl scale deployment rustdesk-hbbs -n $NAMESPACE --replicas=3"
echo ""
