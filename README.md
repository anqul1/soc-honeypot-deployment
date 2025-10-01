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
<img width="795" height="593" alt="image" src="https://github.com/user-attachments/assets/b80e7942-b8ff-4041-861d-54e6409b1ff3" />

