# ceph-cluster-setup
Simple Ceph cluster setup using ``kcli`

Prerequisites: install `kcli` (https://github.com/karmab/kcli)

Or use the following alias to instantiate a `kcli` container with Podman:

``` bash
alias kcli='podman run --net host -it --rm --security-opt label=disable -v $HOME/.ssh:/root/.ssh -v $HOME/.kcli:/root/.kcli -v /var/lib/libvirt/images:/var/lib/libvirt/images -v /var/run/libvirt:/var/run/libvirt -v $PWD:/workdir -v /var/tmp:/ignitiondir quay.io/karmab/kcli:2543a61'
```

Change the SELinux policy to permissive:
``` bash
sudo setenforce 0
```
Make sure `root` can perform `ssh` login:

``` bash
sudo nano /etc/ssh/sshd_config (and set PermitRootLogin to yes)
sudo systemctl restart sshd
```

To create a 3-node Ceph cluster:

``` bash
# Delete any previous installation
kcli delete plan ceph -y
kcli delete network ceph-orch -y && kcli create network -c 192.168.100.0/24 ceph-orch
```

Install the new cluster:

``` bash
kcli create plan -f ./ceph_cluster.yml -P expanded_cluster=true ceph

Or for development:

kcli create plan -f ./ceph_cluster.yml -P ceph_dev_folder=<path-to-your-ceph-src> -P expanded_cluster=true ceph
```

This will create a new 3-node Ceph cluster with the following nodes:
- ceph-node-0 (192.168.100.100)
- ceph-node-1 (192.168.100.101)
- ceph-node-2 (192.168.100.102)

The user can open a shell on any node with a command of the following form, where X is the number of the node):

``` bash
kcli ssh -u root ceph-node-X
```

Launch acephadm shell to manage the cluster:

``` bash
cephadm shell
```
