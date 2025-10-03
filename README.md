# soc-honeypot-deployment

Internal honeypot lab: Cowrie, Dionaea, Glastopf trong VLAN phục vụ SOC detection &amp; training.

## Goal

The goal of this lab is to configure and deploy a Honeypot (Decoy) and to capture the packets that attackers send to the Decoy; log the Honeypot and forward the logs to the Elastic SIEM.
## Architect of this lab

```java
[Manage VLAN: 10.10.10.0/24]
- Admin + SIEM (10.10.10.20)
[Honeypot VLAN: 10.10.10.0/24]
- Honeypot VM (10.10.50.10): Cowrie (SSH/Telnet); Dionaea (malware services); Glastopf (Web)
```
## Step 1: Configure the network
### Honeypot VM (10.10.50.10)
First, you need to install Ubuntu 22.04 live-server, and add 2 NIC into this VM: 
- NIC 1: 10.10.50.10/24 (This one is for stimulate your Honeypot in a VLAN) 
- NIC 2: NAT (And this one help you to connect with the internet to install things for your machine)
You can go to VM > Settings > Add > Network Adapter > Choose NAT

<img width="889" height="900" alt="image" src="https://github.com/user-attachments/assets/fc475c64-8947-4ac7-9328-149a138ad101" />

The NIC1 it's my vmnet3, and i configure it like this:

<img width="694" height="653" alt="image" src="https://github.com/user-attachments/assets/0f2260fe-1e02-4d18-850b-6cc08e7939a8" />

Inside the VM, go to the directory `/etc/netplan/`, find and change the config in yaml
```
cd /etc/netplan/
```
<img width="795" height="593" alt="image" src="https://github.com/user-attachments/assets/b80e7942-b8ff-4041-861d-54e6409b1ff3" />

