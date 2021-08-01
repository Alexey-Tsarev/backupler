# Backupler
This is a shell script which makes backup via rsync / ssh.

# Features
 - Use ssh keys for authorization
 - Use Rsync for quick sync data
 - Rsync options per a host (for example max network speed)
 - A current backup is created based on the previous backup by running "cp -al" (hardlinking)
 - Backup all MySQL tables
 - Logging
 - Post process run, e.g. send a message via Email
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

I use this script to back up VDS hosts
and backup home server to a remote Raspberry Pi 4 host.

---


Good Luck and Best Regards,  
Alexey Tsarev, Tsarev.Alexey at gmail.com
