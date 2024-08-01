#!/bin/bash

# Paths to the original and additional config files
original_config="./kubernetes/bootstrap/talos/talconfig.yaml"
merge_config="./merge_config.yaml"
backup_config="./kubernetes/bootstrap/talos/talconfig_backup.yaml"

# Backup the original config
cp "$original_config" "$backup_config"

# Merge function
merge_configs() {
  # Merge the additional config into the original
  yq eval-all 'select(filename == "'"$original_config"'") * select(filename == "'"$merge_config"'")' "$original_config" "$merge_config" > merged_output.yaml

  # Write the result back to the original config file
  mv merged_output.yaml "$original_config"
}

# Run the merge function
merge_configs

echo "Configuration files have been successfully merged."
