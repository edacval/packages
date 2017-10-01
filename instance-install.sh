#!/bin/bash


if [ $EUID -ne 0 ]; then
    echo 'Need administrator privileges'
    exit 1
fi

WORK_DIR='/home/seafile'
read -rp 'Instance name: ' INSTANCE_NAME
if [ -d  "${WORK_DIR}/${INSTANCE_NAME}" ]; then
    echo "Error: Instance ${INSTANCE_NAME} already exist"
    exit 1
fi
read -rp 'MySQL user: ' MYSQL_USER
read -rsp "MySQL ${MYSQL_USER} password: " MYSQL_USER_PASS; printf "\n"
read -rsp 'MySQL root password: ' MYSQL_ROOT_PASS; printf "\n"

#---------------------------------- MAIN --------------------------------------#

# Make work directory
if ! [ -d "${WORK_DIR}" ]; then
    printf "Making %s Directory... " "${WORK_DIR}"
    useradd -m -r -d /home/seafile -s /usr/bin/nologin seafile || exit 1
    printf "Done\n"
fi

with_seafile='sudo -u seafile'

# Make instance directory
printf "Making %s Directory... " "${WORK_DIR}/${INSTANCE_NAME}"
${with_seafile} mkdir -p "${WORK_DIR}/${INSTANCE_NAME}" || exit 1
printf "Done\n"

cd "${WORK_DIR}/${INSTANCE_NAME}" || exit 1

# Import server
printf "Importing seafile-server in %s... " "${WORK_DIR}/${INSTANCE_NAME}"
${with_seafile} cp -r /usr/share/seafile-server/ ./ || exit 1
printf "Done\n"

# MySQL install
# https://manual.seafile.com/deploy/using_mysql.html
${with_seafile} ./seafile-server/setup-seafile-mysql.sh auto \
    --server-name 'seafile' \
    --server-ip '127.0.0.1' \
    --fileserver-port '8082' \
    --seafile-dir "${WORK_DIR}/${INSTANCE_NAME}/seafile-data/" \
    --use-existing-db '0' \
    --mysql-host '127.0.0.1' \
    --mysql-port '3306' \
    --mysql-user "${MYSQL_USER}" \
    --mysql-user-passwd "${MYSQL_USER_PASS}" \
    --mysql-user-host '127.0.0.1' \
    --mysql-root-passwd "${MYSQL_ROOT_PASS}" \
    --ccnet-db 'ccnet-db' \
    --seafile-db 'seafile-db' \
    --seahub-db 'seahub-db' || exit 1

# Create-admin
${with_seafile} seafile-admin start
${with_seafile} seafile-admin create-admin
${with_seafile} seafile-admin stop

# Systemd service
# https://manual.seafile.com/deploy/start_seafile_at_system_bootup.html
SERVICE_PATH='/etc/systemd/system/seafile-server@.service'

if ! [ -f "${SERVICE_PATH}" ]; then
    printf "Write service %s... " "${SERVICE_PATH}"
    cat <<EOF > "${SERVICE_PATH}"
[Unit]
Description=Next-generation open source cloud storage.
After=syslog.target network.target

[Service]
Type=forking
WorkingDirectory=/home/seafile/%i
ExecStart=/usr/bin/seafile-admin start
ExecStop=/usr/bin/seafile-admin stop
PIDFile=/home/seafile/%i/seafile-data/pids/seaf-server.pid
User=seafile

[Install]
WantedBy=multi-user.target
EOF
    printf "Done\n"
    systemctl daemon-reload # !Important
fi

echo 'Success! You can start:'
echo "systemctl start seafile-server@${INSTANCE_NAME}"
echo 'Webadmin http://127.0.0.1:8000'
exit 0
