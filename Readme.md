Requires ``` rclone restic jq ```

Designed with ``` restic restic 0.17.3 compiled with go1.23.4 on linux/amd64 ```  and ``` rclone v1.60.1-DEV
 ``` in mind

# Ubuntu

``` sudo apt install rclone restic jq ```

create an new rclone remote called

```
onedrive_dn_backups
```


Example .env

```
RESTIC_REPOSITORY="rclone:onedrive_dn_backups:DavidnetBackups/mooiewereld"
RESTIC_PASSWORD="YourSuperSecretBackupPassword"
RESTIC_FORGET_ARGS="--keep-within 14d --keep-daily 14 --keep-weekly 8"
```


Add containername

For example

```
services:
  minecraft:
    image: itzg/minecraft-server
    container_name: mooiewereld
```