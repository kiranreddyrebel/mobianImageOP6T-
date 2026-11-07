sudo tee /usr/local/bin/touch-rebind >/dev/null <<'EOF'
#!/bin/bash
DEV=12-0020
DRV=/sys/bus/i2c/drivers/rmi4_i2c
state() { cat /sys/class/drm/*DSI*/dpms 2>/dev/null | head -1; }
prev=$(state)
while sleep 1; do
  cur=$(state)
  if [ "$prev" != "On" ] && [ "$cur" = "On" ]; then
    sleep 1
    echo $DEV > $DRV/unbind 2>/dev/null
    sleep 1
    echo $DEV > $DRV/bind && logger -t touch-rebind "rebound $DEV after screen on"
  fi
  prev=$cur
done
EOF
sudo chmod +x /usr/local/bin/touch-rebind

sudo tee /etc/systemd/system/touch-rebind.service >/dev/null <<'EOF'
[Unit]
Description=Rebind Synaptics touchscreen when the screen turns on

[Service]
ExecStart=/usr/local/bin/touch-rebind
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl disable --now touch-autobind
sudo systemctl daemon-reload
sudo systemctl enable --now touch-rebind
