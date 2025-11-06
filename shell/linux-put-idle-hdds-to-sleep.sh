#!/bin/bash
# Purpose: Put idle spinning hard drives into standby mode to save power
echo ''
echo 'Starting HDD standby check...'
echo ''
# Loop through all SATA/SCSI drives (/dev/sdX)
for disk in /dev/sd?; do
    echo "[$disk] Checking..."
    sleep 2

    # Check if this is a rotational drive (HDD = 1, SSD = 0)
    is_rotational=$(lsblk -ndo rota "$disk" 2>/dev/null | xargs)
    if [ "$is_rotational" = '0' ]; then
        echo "[$disk] SSD detected - skipping"
        echo ''
        continue
    fi
    
    # Get current power state
    power_state=$(hdparm -C "$disk" 2>/dev/null | awk '/state is:/ {print $4}')
    echo "[$disk] Power state: $power_state"
    
    # If drive is not active/idle, skip I/O check
    if [ "$power_state" != 'active/idle' ]; then
        echo "[$disk] Already in standby - skipping"
        echo ''
        continue
    fi
    
    # Disk is active, check for I/O activity
    echo "[$disk] Checking I/O activity..."
    
    disk_name=$(basename "$disk")
    io_stats_1=$(awk -v disk="$disk_name" '$3 == disk {print $4+$8}' /proc/diskstats)    
    sleep 5
    io_stats_2=$(awk -v disk="$disk_name" '$3 == disk {print $4+$8}' /proc/diskstats)
    
    if [ "$io_stats_1" != "$io_stats_2" ]; then
        echo "[$disk] Active I/O detected - skipping"
        echo ''
        continue
    fi
    
    # Put drive into standby
    echo "[$disk] No I/O detected - putting into standby..."
    /usr/sbin/hdparm -y "$disk" > /dev/null 2>&1
    echo "[$disk] ✓ Standby command sent"
    echo ''
done