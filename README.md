Plumer Server
=============


Pull this repo on the server;

> git clone
> cd plume-server


# Local Certificates
## install mkcert

from [this site](https://docs.raspap.com/features-core/ssl/#creating-a-certificate)
On the server 

> sudo apt-get install libnss3-tools
> sudo wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-arm -O /usr/local/bin/mkcert
> sudo chmod +x /usr/local/bin/mkcert
>
> mkcert -install
> mkcd proxy
> mkcert HOSTNAME IP

It creates a cert.pem and key.pem in ./proxy

On the client (arch)

> download rootCA.pem from the server (server: ~/.local/share/mkcert)
> sudo cp rootCA.pem /etc/ca-certificates/trust-source/anchors
> sudo update-ca-trust

## TODO check ?

https://dev.to/ietxaniz/how-to-implement-https-in-local-networks-using-lets-encrypt-4eh

# Configure plume-server


copy .env.base to .env

> cd plume-server
> cp .env.base .env

Open and edit the env file .env, mainly:

```
MAIN_HOST=exemple.local
INVENTREE_EXT_VOLUME=./plume-data/inventree-data
INVENTREE_DB_PASSWORD=pgpassword
SVN_DOCKER_VOLUME_DIR=./plume-data/svn-data
```

create the INVENTREE_EXT_VOLUME and SVN_DOCKER_VOLUME_DIR directories

## Initialize Inventree

### Initial Database Setup

> docker compose run --rm inventree-server invoke update

### Create Administrator Account

> docker compose run inventree-server invoke superuser

### And NOW you can run 

> docker compose up -d


Enable "Allow same IPN"


## Subversion


### Housekeeping

> create-user.sh

> create-repo.sh


Your users still can't access repositories created on your SVN Server though. 
To manage your user permissions, create the file `/mnt/dockervolumes/svn/authz` (which, by Docker, is then mapped to the container's `/home/svn/authz` path).

An example of [how such an authz file should look](http://svnbook.red-bean.com/en/1.8/svn.serverconfig.pathbasedauthz.html) could be:

```
[repository_name:/]
* = 
user1 = r
user2 = rw
```
("" empty string means no access at all, "r" means read-only and "rw" means read & write permission).




### need lock

There are prehook and post hook on the server side to make locking of FCStd file mandatory.

To avoid commit without lock, and force readonly on FCStd files if not locked :


On each client : nano ~/.subversion/config

``` 
### Section for configuring miscellaneous Subversion options.
[miscellany]
enable-auto-props = yes

### Section for configuring automatic properties.
[auto-props]
*.FCStd = svn:needs-lock=*
```
