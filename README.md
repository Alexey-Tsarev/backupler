# Backupler
This is a simple shell script which makes backup via rsync / ssh.

# Features
 - Use ssh keys for authorization
 - Use Rsync for quick sync data
 - Rsync options per host (for example max network speed)
 - "Current" backup created based on previous backup by running cp -l (hardlink)
 - Backup all MySQL tables
 - Logging
 - Post process run, e.g. send a message via Jabber
 - Archive rotation
 - You receive your backuped data as regular files / directories. No zip / tar.gz
 ~~~
.
├── 2016-09-29_15-02-03
│   ├── etc
│   ├── home
│   ├── opt
│   ├── root
│   ├── srv
│   ├── usr
│   └── var
├── 2016-09-30_15-02-03
│   ├── etc
│   ├── home
│   ├── opt
│   ├── root
│   ├── srv
│   ├── usr
│   └── var
└─── 2016-10-01_15-02-03
    ├── etc
    ├── home
    ├── opt
    ├── root
    ├── srv
    ├── usr
    └── var
~~~

I use this script to backup 2 VDS hosts
and backup home server to remote Raspberry Pi 3 host with 4G USB stick and USB HDD with ZFS.
---


Good Luck and Best Regards,  
Alexey Tsarev, Tsarev.Alexey at gmail.com
