# split-dns configuration

We are using split-dns for DNS, in this configuration we are using unbound on OPNsense which has query forwarding
enabled to k8s-gateway so that we can resolve Ingresses, Services and HTTPRoutes in our cluster.

This only works for HTTPRoutes and Ingresses using internal classes as those are set in k8s-gateway config as for filters.

[k8s-gateway](https://github.com/k8s-gateway/k8s_gateway) is a CoreDNS plugin to resolve different types of external Kubernetes resources, including Services, Ingresses and HTTPRoutes.


