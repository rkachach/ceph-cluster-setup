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

IPv6 network configuration:

To add IPv6 addresses to the cluster nodes, alongside IPv4, on the same network interface configured by **network_interface_name**, set the following parameters:

NOTE: The IPv6 prefix length should be /64
1. **ipv6_prefix_1**: Set your IPv6 prefix (e.g., `2620:52:0:1304`). 
2. **node_ip_offset** : Set your IPv6 offset (e.g., `100`)
3. **network_interface_type**: Set to `ipv6`

Local registry configuration:

If you have a private container registry you wish the nodes to pull the Ceph image from, the following two parameters were added:

- **local_registry_address**: The host (and optional port) of your registry, e.g. `192.168.100.254:5000`.  When defined and non‑empty the bootstrap script will configure the image reference accordingly and a minimal `registries.conf` is created on each node to allow insecure access.
- **local_registry_ceph_image**: The path to the Ceph image inside your registry, e.g. `/ceph/ceph:main`.  This is appended to the address when building the full image name.

Both fields default to empty strings in `ceph_cluster.yml` and may be omitted if you're using the public `quay.ceph.io` image.

In the sample configuration above the nodes are given addresses in the **higher end** of the `192.168.100.0/24` range (starting at `.100`).  This is intentional so the remainder of the pool (e.g. `.1`–`.99`) is available for infrastructure like DNS, DHCP, or an HTTP/registry server.

If you choose to use a private registry, it should be reachable on the same `/24` network; you can run it on one of the unused low‑numbered addresses and push Ceph images there ahead of time.  Doing so dramatically speeds up container downloads compared with pulling from an external source over the wider network, especially when bootstrapping multiple nodes.

The network interface configuration will be automatically applied during cluster setup using `nmcli` to configure the network connection dynamically based on the specified interface name. For the above example the following subnet
will be created on the network interface configured by **network_interface_name**:
- 2620:52:0:1304::/64
Hosts added to the ceph cluster in bootstrap-cluster.sh will be given an IPv6 address with an incrementing offset.

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

For IPv4 this will create a new 3-node Ceph cluster with the following nodes:
- ceph-node-0 (192.168.100.100)
- ceph-node-1 (192.168.100.101)
- ceph-node-2 (192.168.100.102)

For IPv6 this will create a new 3-node Ceph cluster with the following nodes:
- ceph-node-0 (2620:52:0:1304::64)
- ceph-node-1 (2620:52:0:1304::65)
- ceph-node-2 (2620:52:0:1304::66)

The user can open a shell on any node with a command of the following form, where X is the number of the node):

``` bash
kcli ssh -u root ceph-node-X
```

Launch acephadm shell to manage the cluster:

``` bash
cephadm shell
```
