# AG-Talos-Kubernetes

Welcome to my Kubernetes cluster repository, generated from the [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template). This repository leverages Talos Linux for the underlying infrastructure and includes custom modifications to streamline the management and automation of Kubernetes.

## Features

### Core Components
- **Flux**: Implements GitOps to manage and synchronize the cluster's state.
- **cert-manager**: Automates the management of SSL/TLS certificates for Kubernetes services.
- **Cloudflare Integration**: Manages DNS, SSL certificates, and Cloudflare Tunnels for secure access to applications.

## Key Modifications
### Merge Automation
A script, `merge_config.sh`, is used to help merge core Talos configurations (`talconfig.yaml`) with additional configurations (`merge_config.yaml`). This helps with managing Talos updates without manual edits. This has also been added to the taskfile.

## Getting Started

This repository includes the tools needed to quickly bootstrap a Kubernetes cluster. If you're interested in deploying a similar setup, you can use [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) as a starting point, just like I did.

Check the repository’s scripts and documentation for more detailed instructions on setting up Talos and managing the configuration.
