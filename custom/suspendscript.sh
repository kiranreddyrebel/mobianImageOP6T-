#!/usr/bin/env bash
# Clean up the earlier attempts so nothing fights over the device
sudo mkdir -p /usr/lib/systemd/system-sleep/
sudo systemctl disable --now touch-watchdog.service touch-sleep.service 2>/dev/null
sudo rm -f /usr/lib/systemd/system-sleep/rmi4-touch.sh

sudo touch /usr/lib/systemd/system-sleep/rmi4-touch.sh
# 1. Unbind right before suspend
sudo tee /usr/lib/systemd/system-sleep/rmi4-touch.sh >/dev/null <<'EOF'
#!/bin/sh
DEV=12-0020
DRV=/sys/bus/i2c/drivers/rmi4_i2c
[ "$1" = "pre" ] && [ -e "$DRV/$DEV" ] && echo "$DEV" > "$DRV/unbind"
exit 0
EOF
sudo chmod +x /usr/lib/systemd/system-sleep/rmi4-touch.sh

# 2. Auto-rebind service: runs only while the phone is awake
sudo tee /usr/local/bin/touch-autobind >/dev/null <<'EOF'
#!/bin/bash
DEV=12-0020
DRV=/sys/bus/i2c/drivers/rmi4_i2c
while true; do
  if [ -e "/sys/bus/i2c/devices/$DEV" ] && [ ! -e "$DRV/$DEV" ]; then
    sleep 1                                  # let the controller settle after wake
    if echo "$DEV" > "$DRV/bind" 2>/dev/null; then
      logger -t touch-autobind "rebound $DEV"
    else
      logger -t touch-autobind "bind failed, retrying"
      sleep 2
    fi
  fi
  sleep 2
done
EOF
sudo chmod +x /usr/local/bin/touch-autobind

sudo tee /etc/systemd/system/touch-autobind.service >/dev/null <<'EOF'
[Unit]
Description=Rebind Synaptics touchscreen whenever it is unbound

[Service]
ExecStart=/usr/local/bin/touch-autobind
Restart=always

[Install]
WantedBy=multi-user.target
EOF

