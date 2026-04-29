# terraform-multipass-kubernetes
Build a Local Kubernetes cluster the easiest way.

The cluster is built using [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), providing 1 control-plane node and 3 worker nodes, although you can customize this setup.
## Prerequisite:
* [Terraform](https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
* [Multipass](https://multipass.run/)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)



## Resulting nodes:

This lab should standup the following multipass hosts when we select 3 worker nodes

```
multipass list
Name                    State             IPv4             Image
haproxy                 Running           192.168.64.17    Ubuntu 26.04 LTS
master-0                Running           192.168.64.18    Ubuntu 26.04 LTS
                                          172.17.0.1
                                          10.244.36.64
worker-0                Running           192.168.64.20    Ubuntu 26.04 LTS
                                          172.17.0.1
                                          10.244.43.0
worker-1                Running           192.168.64.19    Ubuntu 26.04 LTS
                                          172.17.0.1
                                          10.244.226.64
worker-2                Running           192.168.64.21    Ubuntu 26.04 LTS
                                          172.17.0.1
                                          10.244.133.192
```


Once cloud-init and the kubeadm configuration has complete the following nodes should be present 
```
k get node
NAME       STATUS   ROLES           AGE   VERSION
master-0   Ready    control-plane   10m   v1.34.2
worker-0   Ready    <none>          66s   v1.34.2
worker-1   Ready    <none>          82s   v1.34.2
worker-2   Ready    <none>          68s   v1.34.2
```
Calico is used in this lab for networking between pods with very basic configuration. 
Assuming Calicoctl is installed on your client system can query the calico endpoint

```
calicoctl get ippool
NAME                  CIDR            SELECTOR
default-ipv4-ippool   10.244.0.0/16   all()

calicoctl get node
NAME
master-0
worker-0
worker-1
worker-2
```