# ceph-cluster-setup
Simple Ceph cluster setup by using kcli

Prerequisites: install kcli (https://github.com/karmab/kcli)

Or just use the following alias:

``` bash
alias kcli='podman run --net host -it --rm --security-opt label=disable -v $HOME/.ssh:/root/.ssh -v $HOME/.kcli:/root/.kcli -v /var/lib/libvirt/images:/var/lib/libvirt/images -v /var/run/libvirt:/var/run/libvirt -v $PWD:/workdir -v /var/tmp:/ignitiondir quay.io/karmab/kcli:2543a61'
```

To create a 3-node ceph cluster:

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

This will create a new 3-nodes ceph cluster which has teh following nodes:
 . ceph-node-0 (192.168.100.100)
 . ceph-node-1 (192.168.100.101)
 . ceph-node-2 (192.168.100.102)

Now user can enter to any node by using (where X is the # of the node):

``` bash
kcli ssh -u root ceph-node-X
```

And launch the cephadm shell to manage the cluster:

``` bash
cephadm shell
```
