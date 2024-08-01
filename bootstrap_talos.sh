#!/bin/bash

# Define variables
SCREEN_SESSION="talos-bootstrap"

# Function to check if expect is installed
check_install_expect() {
  if ! command -v expect &> /dev/null; then
    echo "expect is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y expect
  fi
}

# Function to run task configure and respond to prompt
run_task_configure() {
  expect << EOF
  spawn task configure
  expect {
    "Any conflicting config in the kubernetes directory will be overwritten... continue? [y/N]:" {
      send "y\r"
      exp_continue
    }
  }
EOF
}

# Check and install expect if needed
check_install_expect

# Run task configure
run_task_configure

# Wait for task configure to complete
sleep 30

# Check if task configure completed successfully
if ! task configure; then
  echo "task configure failed. Exiting."
  exit 1
fi

# Run the merge_config.sh script
bash merge_config.sh

# Create and start a new screen session
screen -S "$SCREEN_SESSION" -d -m

# Start the task talos:bootstrap in the first window
screen -S "$SCREEN_SESSION" -p 0 -X stuff "task talos:bootstrap\n"

# Create a second window and run the CSR approval loop
screen -S "$SCREEN_SESSION" -X screen -t csr-approve
screen -S "$SCREEN_SESSION" -p csr-approve -X stuff "while true; do kubectl get csr | grep Pending | awk '{print \$1}' | xargs kubectl certificate approve; sleep 10; done\n"

echo "Talos bootstrap and CSR approval are running in the background. Reattach to the screen session using 'screen -r $SCREEN_SESSION'"
