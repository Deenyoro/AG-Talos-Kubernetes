#!/bin/bash

# Start a screen session for task talos:bootstrap
screen -dmS talos_bootstrap bash -c '
    echo "Starting task talos:bootstrap"
    task talos:bootstrap
    echo "task talos:bootstrap completed"
    exec bash
'

# Start another screen session for CSR approval loop
screen -dmS csr_approval bash -c '
    echo "Starting CSR approval loop"
    
    approve_csrs() {
        kubectl get csr | grep Pending | awk '"'"'{print $1}'"'"' | xargs -r kubectl certificate approve
    }
    
    while true; do
        approve_csrs
        sleep 10
    done
'

echo "Started talos:bootstrap in a screen session named 'talos_bootstrap'."
echo "Started CSR approval loop in a screen session named 'csr_approval'."
echo "You can attach to them using: screen -r talos_bootstrap or screen -r csr_approval"
