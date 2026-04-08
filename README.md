Plumer Server
=============

## Initialize Inventree

### Initial Database Setup

> docker compose run --rm inventree-server invoke update

### Create Administrator Account

> docker compose run inventree-server invoke superuser

### And NOW you can run 

> docker compose up -d


## Subversion

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