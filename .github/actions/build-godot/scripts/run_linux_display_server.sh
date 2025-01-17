#!/bin/bash

log_error() {
    echo "::error::$1"
    exit 1
}

log_notice() {
    echo "::notice::$1"
}

log_notice "Setting up Vulkan-compatible display server..."

# Install Vulkan and Xvfb dependencies
sudo apt-get update -y || log_error "Failed to update package list"
sudo apt-get install -y xvfb vulkan-tools mesa-vulkan-drivers || log_error "Failed to install dependencies"

# Set Vulkan ICD and Layer paths for lavapipe
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json
export VK_LAYER_PATH=/usr/share/vulkan/explicit_layer.d

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

# Verify Vulkan support
vulkaninfo | grep -i lavapipe || log_error "Vulkan is not supported on this runner."
