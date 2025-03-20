#!/bin/bash

# Script to configure prerequisites for SonarQube on Debian

set -e

echo "Starting SonarQube prerequisites setup..."

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Update and install required packages
echo "Installing required packages..."
apt update
apt install -y openjdk-17-jdk wget unzip

# Check Java version
echo "Checking Java version..."
java -version
if [[ $? -ne 0 ]]; then
  echo "Java 17 is not installed or not configured correctly." >&2
  exit 1
fi

# Set vm.max_map_count
echo "Setting vm.max_map_count..."
sysctl -w vm.max_map_count=524288
if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
  echo "vm.max_map_count=524288" >> /etc/sysctl.conf
fi

# Set fs.file-max
echo "Setting fs.file-max..."
sysctl -w fs.file-max=131072
if ! grep -q "fs.file-max" /etc/sysctl.conf; then
  echo "fs.file-max=131072" >> /etc/sysctl.conf
fi

# Apply sysctl changes
echo "Applying sysctl changes..."
sysctl -p

# Update user limits
echo "Configuring user limits..."
LIMITS_CONF="/etc/security/limits.conf"
if ! grep -q "sonarqube" "$LIMITS_CONF"; then
  echo "sonarqube   -   nofile   131072" >> "$LIMITS_CONF"
  echo "sonarqube   -   nproc    8192" >> "$LIMITS_CONF"
fi

# Enable PAM limits
PAM_LIMITS="/etc/pam.d/common-session"
if ! grep -q "pam_limits.so" "$PAM_LIMITS"; then
  echo "session required pam_limits.so" >> "$PAM_LIMITS"
fi

PAM_LIMITS_NONINTERACTIVE="/etc/pam.d/common-session-noninteractive"
if ! grep -q "pam_limits.so" "$PAM_LIMITS_NONINTERACTIVE"; then
  echo "session required pam_limits.so" >> "$PAM_LIMITS_NONINTERACTIVE"
fi

# Configure systemd limits for SonarQube service
echo "Configuring systemd limits for SonarQube..."
SYSTEMD_SERVICE="/etc/systemd/system/sonarqube.service"
if [[ ! -f $SYSTEMD_SERVICE ]]; then
  cat <<EOL > $SYSTEMD_SERVICE
[Unit]
Description=SonarQube Service
After=network.target

[Service]
Type=forking
User=sonarqube
Group=sonarqube
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
LimitNOFILE=131072
LimitNPROC=8192
Restart=always

[Install]
WantedBy=multi-user.target
EOL
else
  sed -i '/LimitNOFILE=/d' $SYSTEMD_SERVICE
  sed -i '/LimitNPROC=/d' $SYSTEMD_SERVICE
  sed -i '/\[Service\]/a LimitNOFILE=131072\nLimitNPROC=8192' $SYSTEMD_SERVICE
fi

# Reload systemd and enable the service
echo "Reloading systemd and enabling SonarQube service..."
systemctl daemon-reload
systemctl enable sonarqube

echo "Setup completed! Review the changes and start the SonarQube service using: systemctl start sonarqube"

