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

#--------------------------------- MAIN ---------------------------------------#

# Make work directory
if ! [ -d "${WORK_DIR}" ]; then
    printf "Making %s Directory... " "${WORK_DIR}"
    useradd -m -r -d /home/seafile -s /usr/bin/nologin seafile
    printf "Done\n"
fi

# Make instance directory
printf "Making %s Directory... " "${WORK_DIR}/${INSTANCE_NAME}"
mkdir -p "${WORK_DIR}/${INSTANCE_NAME}"
cd "${WORK_DIR}/${INSTANCE_NAME}" || exit 1
printf "Done\n"

# Import server
printf "Importing seafile-server in %s... " "${WORK_DIR}/${INSTANCE_NAME}"
cp -r /usr/share/seafile-server/ ./
printf "Done\n"

# MySQL install
# https://manual.seafile.com/deploy/using_mysql.html
./seafile-server/setup-seafile-mysql.sh || exit 1

# Create-admin
seafile-admin start
seafile-admin create-admin
seafile-admin stop

# Systemd service
# https://manual.seafile.com/deploy/start_seafile_at_system_bootup.html
SERVICE_PATH='/etc/systemd/system/seafile-server@.service'

if ! [ -f "${SERVICE_PATH}" ]; then
    printf "Write service %s... " "${SERVICE_PATH}"
    cat <<EOF > "${SERVICE_PATH}"
[Unit]
Description=Next-generation open source cloud storage with advanced features on privacy protection and teamwork.
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
fi

chown -R seafile:seafile /tmp/seahub*   # !Important
chown -R seafile:seafile "${WORK_DIR}"  # !Important

echo 'Success! You can start:'
echo "systemctl start seafile-server@${INSTANCE_NAME}"
echo 'Webadmin http://127.0.0.1:8000'
exit 0
