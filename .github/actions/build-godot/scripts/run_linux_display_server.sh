#!/bin/bash

log_error() {
    echo "::error::$1"
    exit 1
}

log_notice() {
    echo "::notice::$1"
}

log_notice "Setting up display server..."

# Update and install dependencies
sudo apt-get update -y || log_error "Failed to update package list"
sudo apt-get install -y xvfb libnss3 libglu1-mesa vulkan-tools mesa-vulkan-drivers libvulkan1 || log_error "Failed to install dependencies"

# Start Xvfb
log_notice "Starting Xvfb..."
export DISPLAY=:99
nohup Xvfb :99 -screen 0 1024x768x24 >/tmp/xvfb.log 2>&1 &

# Verify Xvfb started
sleep 2
if ! pgrep -f "Xvfb :99" >/dev/null; then
    log_error "Failed to start Xvfb. Check /tmp/xvfb.log for details."
fi

log_notice "Xvfb started successfully."
