# Script for backup PVE/PBS server

Скрипты позаимствованы с [этого](https://github.com/DerDanilo/proxmox-stuff) репозитария и доведены до ума


## Резервное копирование
* Скачать [сценарий](https://raw.githubusercontent.com/DerDanilo/proxmox-stuff/master/prox_config_backup.sh)
```cd /root/; wget -qO- https://raw.githubusercontent.com/DerDanilo/proxmox-stuff/master/prox_config_backup.sh```
* Установите переменную окружения постоянного каталога резервных копий ```export BACK_DIR="/path/to/backup/directory"``` или отредактируйте скрипт, чтобы задать ```$DEFAULT_BACK_DIR``` переменную для предпочитаемого вами каталога резервных копий.
* Сделайте скрипт исполняемым ```chmod +x ./prox_config_backup.sh```
* Если вы хотите действовать безопасно, отключите ВСЕ виртуальные машины и контейнеры LXC. (Не обязательно)
* Запустить скрипт ```bash prox_config_backup.sh```

## Уведомление

* Скрипт поддерживает уведомления [healthchecks.io](https://healthchecks.io) , как для размещённой службы, так и для собственного экземпляра. Уведомление отправляется на этапе финальной очистки и возвращает либо 0, сообщая Healthchecks об успешном выполнении команды, либо код ошибки выхода (1-255), сообщающий Healthchecks об ошибке выполнения команды. Чтобы включить:

* Установите `$HEALTHCHECK` переменную на 1
* Укажите `$HEALTHCHECK_URL` в переменной полный URL-адрес пинга для проверки. Не добавляйте ничего после UUID, скрипт добавит флаг статуса.
* 
## Восстановить
❗ ИСПОЛЬЗУЙТЕ ЭТОТ СКРИПТ ТОЛЬКО НА ОДНОЙ И ТОЙ ЖЕ ВЕРСИИ УЗЛА/PROXMOX, В ПРОТИВНОМ СЛУЧАЕ ОН ПОВРЕЖДЕТ ВАШУ СВЕЖУЮ УСТАНОВКУ PROXMOX. ОН ТАКЖЕ НЕ РАБОТАЕТ, ЕСЛИ ВЫ ИСПОЛЬЗУЕТЕ КЛАСТЕР! ❗

Для получения более подробной информации см. №5.

# Bash-скрипты
## Cron
Чтобы настроить автоматическое задание cron по ежемесячному ( ```/etc/cron.weekly``` or ```/etc/cron.daily``` обычному) графику, запустив скрипт `prox_config_backup` , выполните следующие действия:

```wget https://raw.githubusercontent.com/DerDanilo/proxmox-stuff/master/prox_config_backup.sh -O /etc/cron.monthly/prox_config_backup```

Измените ```DEFAULT_BACK_DIR="/mnt/pve/truenas_backup/pve"``` и ```MAX_BACKUPS=5``` привидите к желаемым значениям!

Необязательно: выполните `run-parts` , чтобы проверить наличие ошибок:

`run-parts -v --test /etc/cron.monthly`

## Вручную

На моём компьютере в результате получается сжатый GZIP-файл размером около 1–5 МБ с именем типа «proxmox_backup_proxmoxhostname_2017-12-02.15.48.10.tar.gz».
В зависимости от вашего графика и размера сервера, это может со временем стать проблемой, поэтому не
забудьте настроить обслуживание архива.

Чтобы восстановить, перенесите файл обратно в Proxmox с помощью cp, scp, webmin, флешки или чего угодно.
Я помещаю его обратно в каталог /var/tmp, откуда он был взят.

```
# Unpack the original backup
tar -zxvf proxmox_backup_proxmoxhostname_2017-12-02.15.48.10.tar.gz```
# unpack the tared contents
tar -xvf proxmoxpve.2017-12-02.15.48.10.tar
tar -xvf proxmoxetc.2017-12-02.15.48.10.tar
tar -xvf proxmoxroot.2017-12-02.15.48.10.tar```

# If the services are running, stop them:
for i in pve-cluster pvedaemon vz qemu-server; do systemctl stop $i ; done

# Copy the old content to the original directory:
cp -avr /var/tmp/var/tmp/etc /etc
cp -avr /var/tmp/var/tmp/var /var
cp -avr /var/tmp/var/tmp/root /root

# And, finally, restart services:
for i in qemu-server vz pvedaemon pve-cluster; do systemctl start $i ; done
```
Если всё пойдёт как по маслу, и вы по отдельности восстановили образы виртуальных машин с помощью стандартного процесса Proxmox, то
вы должны вернуться к исходной точке. Но будем надеяться, что до этого не дойдёт.

### Скрипт 

* Скачать  [сценарий](https://raw.githubusercontent.com/DerDanilo/proxmox-stuff/master/prox_config_restore.sh)  
* ```cd /root/; wget -qO- https://raw.githubusercontent.com/DerDanilo/proxmox-stuff/master/prox_config_restore.sh```
* Сделайте скрипт исполняемым ```chmod +x ./prox_config_restore.sh```
* Запустить скрипт ```bash /prox_config_restore.sh proxmox_backup_proxmoxhostname_2017-12-02.15.48.10.tar.gz```

## Источники
https://github.com/DerDanilo/proxmox-stuff
http://ziemecki.net/content/proxmox-config-backups
