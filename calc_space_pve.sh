#!/bin/bash

# Улучшенный скрипт для подсчета общего размера дисков в Proxmox VE

echo "Подсчет общего размера дисков в Proxmox VE..."
echo "=============================================="

TOTAL_SIZE=0
VM_SIZE=0
CT_SIZE=0
VM_COUNT=0
CT_COUNT=0

# Функция для конвертации размера в байты
to_bytes() {
    local size=$1
    local unit=$(echo "$size" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')
    local num=$(echo "$size" | sed 's/[A-Za-z]//g')
    
    case $unit in
        "T") echo "$num * 1099511627776" | bc ;;
        "G") echo "$num * 1073741824" | bc ;;
        "M") echo "$num * 1048576" | bc ;;
        "K") echo "$num * 1024" | bc ;;
        *)   echo "$num * 1073741824" | bc ;; # по умолчанию GB
    esac
}

# Функция для человеко-читаемого формата
human_readable() {
    local bytes=$1
    if [ $(echo "$bytes > 1099511627776" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $bytes/1099511627776" | bc) TB"
    elif [ $(echo "$bytes > 1073741824" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif [ $(echo "$bytes > 1048576" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif [ $(echo "$bytes > 1024" | bc) -eq 1 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "$bytes B"
    fi
}

# Обрабатываем виртуальные машины (VM)
echo "Виртуальные машины:"
for vm_id in $(qm list | awk 'NR>1 {print $1}'); do
    if [ -n "$vm_id" ]; then
        config_file="/etc/pve/qemu-server/${vm_id}.conf"
        if [ -f "$config_file" ]; then
            vm_size_bytes=0
            while IFS= read -r disk_line; do
                if [[ $disk_line =~ size=([0-9.]+[A-Za-z]*) ]]; then
                    disk_size=${BASH_REMATCH[1]}
                    disk_bytes=$(to_bytes "$disk_size")
                    vm_size_bytes=$(echo "$vm_size_bytes + $disk_bytes" | bc)
                fi
            done < <(grep -E '(scsi|sata|virtio|ide)[0-9]+:' "$config_file")
            
            if [ $(echo "$vm_size_bytes > 0" | bc) -eq 1 ]; then
                echo "VM $vm_id: $(human_readable $vm_size_bytes)"
                VM_SIZE=$(echo "$VM_SIZE + $vm_size_bytes" | bc)
                TOTAL_SIZE=$(echo "$TOTAL_SIZE + $vm_size_bytes" | bc)
                VM_COUNT=$((VM_COUNT + 1))
            fi
        fi
    fi
done

echo ""
echo "Контейнеры:"
# Обрабатываем контейнеры (LXC)
for ct_id in $(pct list | awk 'NR>1 {print $1}'); do
    if [ -n "$ct_id" ]; then
        config_file="/etc/pve/lxc/${ct_id}.conf"
        if [ -f "$config_file" ]; then
            ct_size_bytes=0
            # Ищем rootfs
            while IFS= read -r rootfs_line; do
                if [[ $rootfs_line =~ size=([0-9.]+[A-Za-z]*) ]]; then
                    rootfs_size=${BASH_REMATCH[1]}
                    rootfs_bytes=$(to_bytes "$rootfs_size")
                    ct_size_bytes=$(echo "$ct_size_bytes + $rootfs_bytes" | bc)
                fi
            done < <(grep -E '^rootfs:' "$config_file")
            
            # Ищем mpX (mount points)
            while IFS= read -r mp_line; do
                if [[ $mp_line =~ size=([0-9.]+[A-Za-z]*) ]]; then
                    mp_size=${BASH_REMATCH[1]}
                    mp_bytes=$(to_bytes "$mp_size")
                    ct_size_bytes=$(echo "$ct_size_bytes + $mp_bytes" | bc)
                fi
            done < <(grep -E '^mp[0-9]+:' "$config_file")
            
            if [ $(echo "$ct_size_bytes > 0" | bc) -eq 1 ]; then
                echo "CT $ct_id: $(human_readable $ct_size_bytes)"
                CT_SIZE=$(echo "$CT_SIZE + $ct_size_bytes" | bc)
                TOTAL_SIZE=$(echo "$TOTAL_SIZE + $ct_size_bytes" | bc)
                CT_COUNT=$((CT_COUNT + 1))
            fi
        fi
    fi
done

# Конвертируем размеры в GB для удобства
TOTAL_SIZE_GB=$(echo "scale=2; $TOTAL_SIZE / 1073741824" | bc)
VM_SIZE_GB=$(echo "scale=2; $VM_SIZE / 1073741824" | bc)
CT_SIZE_GB=$(echo "scale=2; $CT_SIZE / 1073741824" | bc)

echo ""
echo "=============================================="
echo "Итого:"
echo "Виртуальных машин: $VM_COUNT"
echo "Контейнеров: $CT_COUNT"
echo "Всего объектов: $((VM_COUNT + CT_COUNT))"
echo ""
echo "Размер виртуальных машин: $(human_readable $VM_SIZE) ($VM_SIZE_GB GB)"
echo "Размер контейнеров: $(human_readable $CT_SIZE) ($CT_SIZE_GB GB)"
echo "Общий размер дисков: $(human_readable $TOTAL_SIZE) ($TOTAL_SIZE_GB GB)"
echo "=============================================="

# Дополнительная информация о реальном использовании дискового пространства
echo ""
echo "Дополнительная информация о реальном использовании:"
echo "Общее место на хранилищах:"
df -h | grep -E '/var/lib/vz|/mnt/pve' | awk '{print $6 " : " $2 " использовано: " $3 " свободно: " $4}'
