#!/bin/bash

# Define variables
ORIGINAL_CONFIG="./kubernetes/bootstrap/talos/talconfig.yaml"
MERGE_CONFIG="./merge_config.yaml"
BACKUP_CONFIG="./kubernetes/bootstrap/talos/talconfig_backup.yaml"
SCREEN_SESSION="talos-bootstrap"

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

# Function to merge configurations
merge_configs() {
  # Backup the original config
  cp "$ORIGINAL_CONFIG" "$BACKUP_CONFIG"
  # Merge the additional config into the original
  yq eval-all 'select(filename == "'"$ORIGINAL_CONFIG"'") * select(filename == "'"$MERGE_CONFIG"'")' "$ORIGINAL_CONFIG" "$MERGE_CONFIG" > merged_output.yaml
  # Write the result back to the original config file
  mv merged_output.yaml "$ORIGINAL_CONFIG"
}

# Run task configure
run_task_configure

# Merge configurations
merge_configs

# Create and start a new screen session
screen -S "$SCREEN_SESSION" -d -m

# Start the task talos:bootstrap in the first window
screen -S "$SCREEN_SESSION" -X screen -t bootstrap
screen -S "$SCREEN_SESSION" -p bootstrap -X stuff "task talos:bootstrap\n"

# Create a second window and run the CSR approval loop
screen -S "$SCREEN_SESSION" -X screen -t csr-approve
screen -S "$SCREEN_SESSION" -p csr-approve -X stuff "while true; do kubectl get csr | grep Pending | awk '{print \$1}' | xargs kubectl certificate approve; sleep 10; done\n"

echo "Talos bootstrap and CSR approval are running in the background. Reattach to the screen session using 'screen -r $SCREEN_SESSION'"
