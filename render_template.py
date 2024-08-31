from jinja2 import Template

# Define your test data
data = {
    "talosVersion": "v1.0.0",
    "kubernetesVersion": "v1.20.0",
    "bootstrap_cluster_name": "test-cluster",
    "bootstrap_controller_vip": "192.168.1.100",
    "bootstrap_cluster_domain": "example.local",
    "bootstrap_pod_network": "10.244.0.0/16",
    "bootstrap_service_network": "10.96.0.0/12",
    "bootstrap_tls_sans": ["example.com", "192.168.1.1"],
    "bootstrap_node_inventory": [
        {"name": "node1", "address": "192.168.1.101", "controller": True, "disk": "/dev/sda", "mac_addr": "00:1A:2B:3C:4D:5E"},
        {"name": "node2", "address": "192.168.1.102", "controller": False, "disk": "1234567890", "mac_addr": "00:1A:2B:3C:4D:5F"}
    ],
    "bootstrap_secureboot": {"enabled": False},
    "bootstrap_schematic_id": "default-id",
    "bootstrap_vlan": 100
}

# Your Jinja2 template as a string
template_str = """
# yaml-language-server: $schema=https://raw.githubusercontent.com/budimanjojo/talhelper/master/pkg/config/schemas/talconfig.json
---
# renovate: datasource=docker depName=ghcr.io/siderolabs/installer
talosVersion: {{ talosVersion }}
# renovate: datasource=docker depName=ghcr.io/siderolabs/kubelet
kubernetesVersion: {{ kubernetesVersion }}

clusterName: {{ bootstrap_cluster_name | default('thepatriots', true) }}
endpoint: "https://{{ bootstrap_controller_vip }}:6443"
domain: {{ bootstrap_cluster_domain | default('home.local', true) }}
allowSchedulingOnMasters: true
clusterPodNets:
  - {{ bootstrap_pod_network.split(',')[0] }}
clusterSvcNets:
  - {{ bootstrap_service_network.split(',')[0] }}
additionalApiServerCertSans: &sans
  - {{ bootstrap_controller_vip }}
  - 127.0.0.1 # KubePrism
  {% for item in bootstrap_tls_sans %}
  - {{ item }}
  {% endfor %}
additionalMachineCertSans: *sans

# Disable built-in Flannel to use Cilium
cniConfig:
  name: none

nodes:
  {% for item in bootstrap_node_inventory %}
  - hostname: {{ item.name }}
    ipAddress: {{ item.address }}
    controlPlane: {{ (item.controller) | string | lower }}
    {% if item.disk.startswith('/') %}
    installDisk: {{ item.disk }}
    {% else %}
    installDiskSelector:
      serial: {{ item.disk }}
    {% endif %}
    {% if bootstrap_secureboot.enabled %}
    machineSpec:
      secureboot: true
    talosImageURL: "factory.talos.dev/installer-secureboot/{{ item.schematic_id | default(bootstrap_schematic_id) }}"
    {% else %}
    talosImageURL: "factory.talos.dev/installer/{{ item.schematic_id | default(bootstrap_schematic_id) }}"
    {% endif %}
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: {{ item.mac_addr | lower }}
        {% if bootstrap_vlan %}
        vlans:
          - vlanId: {{ bootstrap_vlan }}
        {% endif %}
  {% endfor %}
"""

# Create a Template object
template = Template(template_str)

# Render the template with data
rendered_yaml = template.render(data)

# Print the rendered YAML
print(rendered_yaml)
