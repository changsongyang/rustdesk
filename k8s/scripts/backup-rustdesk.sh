#!/bin/bash
# backup-rustdesk.sh - RustDesk 数据备份脚本

set -e

NAMESPACE="${NAMESPACE:-rustdesk}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo "RustDesk 数据备份脚本"
echo "=========================================="
echo "命名空间: $NAMESPACE"
echo "备份目录: $BACKUP_DIR"
echo "备份日期: $DATE"
echo ""

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "错误: kubectl 未安装"
    exit 1
fi

# 获取 PVC 列表
pvc_list=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

if [ -z "$pvc_list" ]; then
    echo "警告: 未找到 PVC，跳过备份"
    exit 0
fi

# 备份每个 PVC
for pvc in $pvc_list; do
    echo "备份 PVC: $pvc"

    # 获取 PVC 详情
    pvc_info=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o yaml)
    storage_class=$(echo "$pvc_info" | grep -o 'storageClassName:.*' | cut -d' ' -f2)
    size=$(echo "$pvc_info" | grep -o 'storage:.*' | cut -d':' -f2 | tr -d ' ')

    # 创建备份元数据
    cat > "$BACKUP_DIR/${pvc}_${DATE}.meta" <<EOF
PVC Name: $pvc
Backup Date: $DATE
Storage Class: $storage_class
Size: $size
Namespace: $NAMESPACE
EOF

    # 查找使用此 PVC 的 Pod
    pod=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.volumes[*].persistentVolumeClaim.claimName}' | tr ' ' '\n' | grep "^${pvc}$" -B 1 | head -1 || echo "")

    if [ -n "$pod" ]; then
        # 使用 Pod 进行备份
        echo "  使用 Pod: $pod"
        kubectl exec -n "$NAMESPACE" "$pod" -- tar czf "/tmp/${pvc}.tar.gz" -C /data . 2>/dev/null || {
            echo "  警告: 无法创建备份，可能 Pod 未运行"
            continue
        }

        # 复制备份文件
        kubectl cp "$NAMESPACE/$pod:/tmp/${pvc}.tar.gz" "$BACKUP_DIR/${pvc}_${DATE}.tar.gz"

        # 清理 Pod 内的临时文件
        kubectl exec -n "$NAMESPACE" "$pod" -- rm -f "/tmp/${pvc}.tar.gz"

        echo "  ✓ 备份完成: $BACKUP_DIR/${pvc}_${DATE}.tar.gz"
    else
        echo "  警告: 未找到使用此 PVC 的 Pod，跳过备份"
    fi
done

# 清理旧备份
echo ""
echo "清理旧备份 (保留最近 $RETENTION_DAYS 天)..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name "*.meta" -mtime +"$RETENTION_DAYS" -delete
echo "✓ 清理完成"

# 生成备份清单
echo ""
echo "当前备份清单:"
ls -lh "$BACKUP_DIR"/*_"$DATE".tar.gz 2>/dev/null || echo "  无当日备份"

# 计算备份大小
total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "备份目录总大小: $total_size"

echo ""
echo "=========================================="
echo "备份完成!"
echo "=========================================="
echo ""
echo "恢复命令示例:"
for pvc in $pvc_list; do
    echo "  kubectl cp $BACKUP_DIR/${pvc}_<日期>.tar.gz <namespace>/<pod>:/tmp/"
    echo "  kubectl exec -n $NAMESPACE <pod> -- tar xzf /tmp/${pvc}.tar.gz -C /data"
done
