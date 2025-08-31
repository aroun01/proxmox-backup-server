#!/bin/bash

# Скрипт бэкапа для cron
# /usr/local/bin/pve-host-backup.sh

# Настройки
PBS_SERVER="backup.asmo.media:8007"
PBS_STORAGE="STORAGE"
HOST_DIR="/mnt/pve/pve-backup"
LOG_FILE="/var/log/pve-host-backup.log"
BACKUP_NAME="pve-1-host"

# Логируем начало
echo "==============================================" >> "$LOG_FILE"
echo "$(date): Начало бэкапа директории $HOST_DIR" >> "$LOG_FILE"

# Выполняем бэкап
proxmox-backup-client backup \
    --repository "root@pam@$PBS_SERVER:$PBS_STORAGE" \
    "$BACKUP_NAME.pxar:$HOST_DIR" >> "$LOG_FILE" 2>&1

# Проверяем результат
if [ $? -eq 0 ]; then
    echo "$(date): ✅ Бэкап успешно завершен" >> "$LOG_FILE"
    exit 0
else
    echo "$(date): ❌ Ошибка при выполнении бэкапа" >> "$LOG_FILE"
    exit 1
fi
