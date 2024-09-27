# split-dns configuration

We are using split-dns for DNS, in this configuration it's done with the use of dnsdist, and bind.


## Configuring Bind

The container will not start up without being properly configured first.

First thing needed is to generate the rndc-key and externaldns keys.
On Ubuntu, useful commands to do so are provided by installing bind9-utils package.

The key itself is generated with: `rndc-confgen -c rndc.key`.



named.conf would look something like the following:
```
# Only define the known VLAN subnets as trusted
acl "trusted" {
  10.10.11.0/24;   # LAN
  172.16.10.0/24;    # CONTAINERS
  10.10.12.0/24;   #clusterVLAN
  10.10.13.0/24;   #serverVLAN
};

options {
  directory "/var/cache/bind";
  listen-on { 127.0.0.1; 172.16.10.3; };
  #listen-on-v6 { fdbc:baa4:65a9::3; };

  allow-recursion {
    trusted;
  };
  allow-transfer {
    none;
  };
  allow-update {
    none;
  };
};

logging {
  channel stdout {
    stderr;
    severity info;
    print-category yes;
    print-severity yes;
    print-time yes;
  };
  category security { stdout; };
  category dnssec   { stdout; };
  category default  { stdout; };
};

include "/etc/bind/rndc.key";
include "/etc/bind/externaldns.key";


controls {
  inet 127.0.0.1 allow { localhost; } keys { "rndc-key"; };
};

zone "${SECRET_DOMAIN}." {
  type master;
  file "/etc/bind/zones/db.${SECRET_DOMAIN}>";
  journal "/var/cache/bind/db.${SECRET_DOMAIN}.jnl";
  allow-transfer {
    key "externaldns";
  };
  update-policy {
    grant externaldns zonesub ANY;
  };
};
```

