# VolSync with SOPS

Each and every app to be backed up needs the following:
- secret per pvc (RESTIC_REPOSITORY, RESTIC_PASSWORD and S3 aka AWS credentials, only restic_repository needs to change per pvc)
- The files are replicationdestionation, replicationsource (backup from pvc), pvc itself and kustomization.yaml.



## What does each file do?


replicationdestination: Responsible for specifying where to restore from
pvc: Actual PVC which will use replicationdestination to restore the backup, and if it doesn't have a backup, it will create an empty pvc
replicationsource: The actual backup from pvc
