#! /bin/bash
sudo dmesg -c 
echo "*** systemctl stop systemd-journald"
sudo systemctl stop systemd-journald
sudo rm -rf /var/log/journal/*
sudo systemctl start systemd-journald
echo "*** truncate syslog kern.log daemon.log"
sudo truncate -s 0 /var/log/syslog
sudo truncate -s 0 /var/log/kern.log 
sudo truncate -s 0 /var/log/daemon.log
sudo rm -rf /var/log/syslog.* /var/log/kern.log.*  /var/log/daemon.log.*

echo "*** rmdir media dir"
sudo rmdir /media/$USER/* 2>/dev/null 

echo "*** rm recently-used.xbel"
rm -rf ~/.local/share/recently-used.xbel 

