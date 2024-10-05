# ceph-troubleshooting


## Importing of external cluster

When executing the import script, it should be done with much care so that the pools referenced in the command actually
exist and are right.

When the command is executed like this:
```shell
python3 create-external-cluster-resources.py --rbd-data-pool-name SSD4x6_pool --cephfs-filesystem-name SSD4x6 --namespace rook-ceph --format bash
```

The results are that storageclass gets that rbd-data-pool-name set inside parameters, and it will not be simple to see why it's failing
to provision volumes.

In the case of this cluster, the rbd pool name was `SSD4x1_pool` instead.


### cephfs provisioning fails

There needs to be an subvolume group called csi by default, which should be provisioned automatically but often are not in external cluster situations.

It can be created either manually from cli, or from the ceph dashboard under File Systems -> Chooce right pool -> subvolume groups -> add new with name csi. Afterwards it should be able to provision the volume.


Slack thread about the whole thing: https://rook-io.slack.com/archives/CG3HUV94J/p1727441007561519
More information about troubleshooting csi: https://github.com/rook/rook/blob/master/Documentation/Troubleshooting/ceph-csi-common-issues.md & permissions: https://github.com/ceph/ceph-csi/blob/devel/docs/capabilities.md
