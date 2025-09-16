# split-dns

We are using split-dns for DNS, in this configuration we are using unbound on OPNsense which has query forwarding
enabled to k8s-gateway so that we can resolve Ingresses, Services and HTTPRoutes in our cluster.

This only works for HTTPRoutes and Ingresses using internal classes as those are set in k8s-gateway config as for filters.

[k8s-gateway](https://github.com/k8s-gateway/k8s_gateway) is a CoreDNS plugin to resolve different types of external Kubernetes resources, including Services, Ingresses and HTTPRoutes.


## Traffic paths

Some applications might not support being accessed by different hostnames internally and externally, for example Zammad
thus their access will be handled via a cloudflare tunnel, which also means they will not be accessible without internet access.

These are easy to spot that if the HTTPRoute/Ingress doesn't have a lan suffix, they are likely only accessible via the tunnel.

In that case the traffic follows this path:
```
Client -> OPNsense (unbound) -> Cloudflare -> Cloudflare Tunnel (cloudflared) -> Ingress controller or Cilium gateway -> Zammad Pod
```
(Note that the rules for cloudflared are handled in a configmap in the k8s cluster, in the same directory as cloudflared)

For other applications the traffic path is as follows:
```
Client -> OPNsense (unbound) -> k8s-gateway -> Ingress controller or Cilium gateway -> Application Pod
```



### external-dns (External, managing DNS records in Cloudflare)

For applications that need to be accessible via a custom domain name, we are using external-dns to manage DNS records in Cloudflare.
External-dns is configured upsert-only, meaning it will not delete any records; this is to avoid accidental deletions.
This, however, means that if you delete an Ingress or HTTPRoute, the DNS record will remain in Cloudflare until you manually delete it.

The annotations below will only work if the Ingress or HTTPRoute is using an external class and domains w/o lan suffix, as external-dns is configured to only monitor those.

Annotations for external-dns:
```yaml
external-dns.alpha.kubernetes.io/hostname: "yourdomain.com" # The domain name to create the DNS record for
external-dns.alpha.kubernetes.io/ttl: "300" # Time to live for the DNS record
external-dns.alpha.kubernetes.io/target: "target.domain.com" # Optional, if you want to point to a different domain via CNAME
external-dns.alpha.kubernetes.io/cloudflare-proxied: "true" # Optional, if you want to enable Cloudflare proxy, defaults to true in current config
```
(More [available](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/annotations/annotations.md), but most important are these four)

