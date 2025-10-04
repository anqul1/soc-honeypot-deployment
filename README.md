# soc-honeypot-deployment

Internal honeypot lab: Cowrie, Dionaea, Glastopf trong VLAN phục vụ SOC detection &amp; training.

## Goal

The goal of this lab is to configure and deploy a Honeypot (Decoy) and to capture the packets that attackers send to the Decoy; log the Honeypot and forward the logs to the Elastic SIEM. We will use 3 Honeypots to have some "depth" logs in each attack vector to analysis (for SOC value - commands, samples, payloads, forensics. you’ll need specialized honeypots)
## Architect of this lab

```java
[Manage VLAN: 10.10.10.0/24]
- Admin + SIEM (10.10.10.20/24)
- My Laptop ;)
[Honeypot VLAN: 10.10.50.0/24]
- Honeypot VM (10.10.50.10/24): Cowrie (SSH/Telnet); Dionaea (malware services); Glastopf (Web)
- Ubuntu 22.04 live-server on VMWare
[Attacker's Compromised computer on VMWare (Linux): 10.10.50.20/24]
[Router: connect 2 computers from different VLANs]
- Forwarding Honeypot logs to SIEM in different VLAN
- Using Alpine Linux (light distro) because I'm using my 4 years old laptop =))
```
## Step 1: Configure the network
### Honeypot VM (10.10.50.10/24)
First, you need to install Ubuntu 22.04 live-server, and add 2 NIC into this VM: 
- NIC 1: 10.10.50.10/24 (This one is for stimulate your Honeypot in a VLAN) (in my lab it's vmnet3)
- NIC 2: NAT (And this one help you to connect with the internet to install things for your machine) 
You can go to VM > Settings > Add > Network Adapter > Choose NAT

<img width="371" height="354" alt="image" src="https://github.com/user-attachments/assets/6b34a7a0-21ba-4a30-8fba-a813a9d68926" />

The NIC1 it's my vmnet3, and i configure it like this:

<img width="694" height="653" alt="image" src="https://github.com/user-attachments/assets/0f2260fe-1e02-4d18-850b-6cc08e7939a8" />

Inside the VM, go to the directory `/etc/netplan/`, find and change your config in yaml
```
sudo nano /etc/netplan/00-installer-config.yaml
```
For me, my NIC1 is corresponding to ens33, NIC2 is corresponding to ens37, change the config like following:
<img width="636" height="163" alt="image" src="https://github.com/user-attachments/assets/b4d33dd2-570e-46af-ae51-e151e00e0d07" />

Then, we need to renew IP for ens37 `sudo dhclient -v ens37` (I already set up the NIC1 when I install the OS and add the NIC2 after that), and next you need to run `sudo netplan apply` 


### ADMIN + SIEM (10.10.10.20/24)

Cấu hình route lại alpine: `route -p add 10.10.50.0 mask 255.255.255.0 10.10.10.1`
It's my laptop so the configuration will be more easily, first you need to change the adapter settings:
```bash
#add rule
netsh advfirewall firewall add rule name="Allow ICMP from Honeypot" `
  dir=in action=allow protocol=icmpv4 remoteip=10.10.50.10
netsh advfirewall firewall add rule name="Allow Syslog from Honeypot" `
  dir=in action=allow protocol=udp localport=514 remoteip=10.10.50.10
#check rule
 Get-NetFirewallRule -DisplayName "*from Honeypot*"| Format-List *
```



### Router-layer3 (10.10.50.1/24) (10.10.10.1/24) (192.168.244.20/24)
#### Install OS
- Now we need to install a very light distro of linux - Alpine. Link to the distro: `https://www.alpinelinux.org/downloads/` then download the standard version (the x86_64 for my vmware)
- Go to create a new virtual machine -> Choose your ISO File -> VMWare cannot detect the OS so you need to choose `Other Linux 5.x kernel 64-bit`

<img width="503" height="524" alt="image" src="https://github.com/user-attachments/assets/18cb7f04-2e55-4c7a-88fe-9a2998cb2e32" />

#### Config for routing

- Add 2 NICs to your VM: 
  - VMnet3 (10.10.50.0/24)
  - VMnet4 (10.10.10.0/24)
<img width="372" height="325" alt="image" src="https://github.com/user-attachments/assets/1d8040a4-78e8-43d6-900f-b38fdaa5035d" />

- Check if 2 NICs detected, run command: `ip a`
<img width="826" height="210" alt="image" src="https://github.com/user-attachments/assets/6121664a-0cc3-4825-b966-7771ed53f39a" />

- As you can see here now we have `eth0` and `eth1`, let's assign IP for each NIC:

```bash
#vmnet3 (route to honeypot)
ip addr add 10.10.50.1/24 dev eth0
ip link set eth0 up
#vmnet4 (route to Admin + siem)
ip addr add 10.10.10.1/24 dev eth1
ip link set eth1 up
```
- The result:
<img width="767" height="352" alt="image" src="https://github.com/user-attachments/assets/1665c011-faaa-4ce3-ac88-79ac6752ea95" />

- Next, we need to turn on IP Forwarding (Allow it to routing on the routing table):
  - Run `vi /etc/sysctl.conf`
  - Add this line: `net.ipv4.ip_forward=1`
  - Then run: `sysctl -p` to apply new config.
  - <img width="463" height="163" alt="image" src="https://github.com/user-attachments/assets/b98c419f-9911-4946-9ad6-56ec6164d2fd" />

- Let's test it from your Honeypot VM, let's ping to Admin at `10.10.10.20` (My real PC):
  - `ping 10.10.10.20`
  - <img width="611" height="185" alt="image" src="https://github.com/user-attachments/assets/4f915dbb-beec-4d1b-922d-2f0138cbc5e7" />
  
  - As you can see, now i can ping between different interfaces (stimulate my VLAN)

- Now i realize i forgot to add a NIC for install iptables ~~, let's do it:
  - Add new NIC to the VM -> set it to NAT
  - My VMnet8 (NAT) is at `192.168.244.0/24`, so i will set a static IP for this router (192.168.244.20/24)
  - Run command below to assign the IP to this NIC:
  ```bash
  ip addr add 192.168.244.20/24 dev eth2
  ip link set eth2 up 
  ip route add default via 192.168.244.2 #my gateway
  ```
  > **⚠️ Notice:** On VMWare the default gateway of NAT is usually 192.168.x.2
  - now let's test the connection by ping to my gateway and 8.8.8.8:
  - <img width="534" height="346" alt="image" src="https://github.com/user-attachments/assets/6ca5be53-1ff6-47cc-9db1-3d8c61322133" />

- Summary: <img width="476" height="151" alt="image" src="https://github.com/user-attachments/assets/8cce5cf5-18ef-4fe8-98d5-ff1b48764566" />


We're done the first job!

## Step 2: Setup the firewall
### Honeypot VM (10.10.50.10)
```sh
# Reset all rule -> default rule
sudo ufw reset
# It's a honeypot so we need to set the rule to deny-by-default
sudo ufw default deny incoming
sudo ufw default deny outgoing
# Allow incoming from attacker in VLAN to honeypot ports + ICMP
sudo ufw allow from 10.10.50.0/24 to any port 2222 proto tcp   # Cowrie (SSH fake)
sudo ufw allow from 10.10.50.0/24 to any port 8080 proto tcp   # Glastopf (HTTP)
sudo ufw allow from 10.10.50.0/24 to any port 1445 proto tcp   # Dionaea mapped SMB
sudo ufw allow from 10.10.50.0/24 to any proto icmp # allow ICMP (ping) from VLAN of the Honeypot (where the attacker located)
# Allow incoming from Management (Admin/SIEM)
sudo ufw allow from 10.10.10.20 to any port 22 proto tcp     # Admin SSH
sudo ufw allow out to 10.10.10.20 port 5044 proto tcp   # Filebeat -> Logstash/Logstash-beats
sudo ufw allow out to 10.10.10.20 port 514 proto udp    # Syslog
# On the NIC2 (ens37 - the NAT NIC)
# DNS (UDP/TCP) on NAT interface so name resolution works
sudo ufw allow out on ens37 to any port 53 proto udp
sudo ufw allow out on ens37 to any port 53 proto tcp
# DHCP client 
sudo ufw allow out on ens37 to any port 67 proto udp
# TEMPORARY: allow HTTP/HTTPS on NAT for apt/docker pull 
sudo ufw allow out on ens37 to any port 80 proto tcp
sudo ufw allow out on ens37 to any port 443 proto tcp
#enable the rule
sudo ufw enable
#delete the allowing rule on NAT for apt/docker pull after install full of your materials
sudo ufw status numbered
sudo ufw delete {the numbered allowing rule on ens37}
```
### Router-Layer3 (10.10.50.1/24) (10.10.10.1/24) (192.168.244.20/24)
#### Install nftables
  - <img width="737" height="143" alt="image" src="https://github.com/user-attachments/assets/8aceab2d-f08c-400b-b547-fa594bff43de" />
  - <img width="438" height="116" alt="image" src="https://github.com/user-attachments/assets/e767b33f-c883-414a-b367-3302433781d6" />
  - And i failed, as you can see when i run `apk update`, it's go to `/media/cdrom/apks` (find in cd iso, not online repo).
  - Here is how to fix this: `vi /etc/apk/repositories` > Add online repo of alpinelinux:
  ```bash
  http://dl-cdn.alpinelinux.org/alpine/v3.22/main
  http://dl-cdn.alpinelinux.org/alpine/v3.22/community
  ```
  - Then add Google DNS in `resolv.conf`:
  ```sh
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  ```
  - Re-run `apk update` now you're able to install nftables : <img width="602" height="310" alt="image" src="https://github.com/user-attachments/assets/2a24b11e-c951-49c7-a420-89e58c5a7903" />

  
