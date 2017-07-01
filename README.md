# nube
NixOs and Kubernetes.

# Getting Started
The easiest way to get get started, if you are not running NixOs, is to install nix.

```
$ curl https://nixos.org/nix/install | sh
```

Or, if you don't trust the script, download first, inspect it, then run it.
You should now have nix running on your system. Now, install NixOps.
First, make sure the package index is up to date.

```
$ nix-channel --update
```

Then:

```
$ nix-env -i nixops
```

# Launching
`kube-master-and-node.nix` contains a nixos configuration module for a virtualbox VM
with a single master/node kubernetes. The steps to launch it are as follows:


```
$ nixops create -d kube kube-master-and-node.nix
```

This creates the the deployment. You can list deployments with `nixops list`.

```
$ nixops list
+--------------------------------------+------+------------------------+------------+------+
| UUID                                 | Name | Description            | # Machines | Type |
+--------------------------------------+------+------------------------+------------+------+
| 6989b74f-5e54-11e7-9547-02420698efdb | kube | Unnamed NixOps network |          0 |      |
+--------------------------------------+------+------------------------+------------+------+
```

To actually _create_ the machine from this deployment we use `nixops deploy`.

```
$ nixops deploy -d kube
kube> creating VirtualBox VM...
kube> Virtual machine 'nixops-6989b74f-5e54-11e7-9547-02420698efdb-kube' is created and registered.
kube> UUID: ef0dc49d-190d-44d2-b217-71a47fb9cf11
...
```
This will take a minute or so. Once it is complete, run `nixops info` to see info about this deployment.

```
$ nixops info
Network name: kube
Network UUID: 6989b74f-5e54-11e7-9547-02420698efdb
Network description: Unnamed NixOps network
Nix expressions: /home/chaospie/repos/nix-kube/kube-master-and-node.nix

+------+-----------------+------------+--------------------------------------------------+----------------+
| Name |      Status     | Type       | Resource Id                                      | IP address     |
+------+-----------------+------------+--------------------------------------------------+----------------+
| kube | Up / Up-to-date | virtualbox | nixops-6989b74f-5e54-11e7-9547-02420698efdb-kube | 192.168.56.103 |
+------+-----------------+------------+--------------------------------------------------+----------------+
```

# Testing Kubernetes
Now we have a machine, and kubernetes should be running. We can ssh into it as follows.

```
$ nixops ssh kube
```

To check kube's status:

```
# kubectl get nodes
NAME      STATUS    AGE
kube      Ready     2m
```
Nice!

# A Quick Test
```
# kubectl run my-nginx --image=nginx --replicas=2 --port=80
deployment "my-nginx" created

# kubectl get pods
NAME                       READY     STATUS    RESTARTS   AGE
my-nginx-379829228-2241q   1/1       Running   0          56s
my-nginx-379829228-g8frn   1/1       Running   0          56s

# kubectl get services
NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.10.10.1   <none>        443/TCP   5m

[root@kube:~]# kubectl get deployment
NAME       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
my-nginx   2         2         2            2           1m

[root@kube:~]# kubectl expose deployment my-nginx --port=80 --type=LoadBalancer
service "my-nginx" exposed

# kubectl get services
NAME         CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
kubernetes   10.10.10.1    <none>        443/TCP        5m
my-nginx     10.10.10.63   <pending>     80:30294/TCP   2s

# curl 10.10.10.63
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>

```
