#!/bin/bash

# Упрощенная версия скрипта

echo "Подсчет общего размера дисков в Proxmox VE..."
echo "=============================================="

TOTAL_SIZE_GB=0
VM_COUNT=0
CT_COUNT=0

# Обрабатываем виртуальные машины
for vm_id in $(qm list | awk 'NR>1 {print $1}'); do
    if [ -n "$vm_id" ]; then
        config_file="/etc/pve/qemu-server/${vm_id}.conf"
        if [ -f "$config_file" ]; then
            vm_size=$(grep -oP 'size=\K[0-9.]+[A-Za-z]*' "$config_file" | head -1)
            if [ -n "$vm_size" ]; then
                echo "VM $vm_id: $vm_size"
                # Упрощенный подсчет (предполагаем, что размер в GB)
                size_num=$(echo "$vm_size" | sed 's/[A-Za-z]//g')
                TOTAL_SIZE_GB=$(echo "$TOTAL_SIZE_GB + $size_num" | bc)
                VM_COUNT=$((VM_COUNT + 1))
            fi
        fi
    fi
done

# Обрабатываем контейнеры
for ct_id in $(pct list | awk 'NR>1 {print $1}'); do
    if [ -n "$ct_id" ]; then
        config_file="/etc/pve/lxc/${ct_id}.conf"
        if [ -f "$config_file" ]; then
            rootfs_size=$(grep -oP 'rootfs:.*size=\K[0-9.]+[A-Za-z]*' "$config_file" | head -1)
            if [ -n "$rootfs_size" ]; then
                echo "CT $ct_id: $rootfs_size"
                size_num=$(echo "$rootfs_size" | sed 's/[A-Za-z]//g')
                TOTAL_SIZE_GB=$(echo "$TOTAL_SIZE_GB + $size_num" | bc)
                CT_COUNT=$((CT_COUNT + 1))
            fi
        fi
    fi
done

echo "=============================================="
echo "Итого:"
echo "Виртуальных машин: $VM_COUNT"
echo "Контейнеров: $CT_COUNT"
echo "Всего объектов: $((VM_COUNT + CT_COUNT))"
echo "Общий размер дисков: ${TOTAL_SIZE_GB} GB"
echo "=============================================="
