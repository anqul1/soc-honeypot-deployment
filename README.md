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

> **⚠️ Notice: Configure to route back to Alpine router (10.10.50.1)**:

Run this command to forward traffic the traffic of our Honeypot(10.10.50.10) to ADMIN+SIEM(10.10.10.20) through Router: `sudo ip route add 10.10.10.0/24 via 10.10.50.1`

I use it to test the connection, if you want a persistent route, you need to `sudo nano /etc/netplan/00-installer-config.yaml` and change the config like this:
>I used the `gateway4` param first but it warned me: `gateway4 has been deprecated` so i user the routes instead.
<img width="821" height="360" alt="image" src="https://github.com/user-attachments/assets/f7320f09-055f-46f2-8041-2a5036486c76" />




### ADMIN + SIEM (10.10.10.20/24)

Cấu hình route lại alpine: `route -p add 10.10.50.0 mask 255.255.255.0 10.10.10.1`

It's my laptop so the configuration will be more easily, first you need to change the adapter settings:
- Turn off IPv4 on vmnet3 (so the traffic will not go straight from our PC to the Honeypot)
- <img width="448" height="585" alt="image" src="https://github.com/user-attachments/assets/2703f8de-bae8-457a-bc1b-1b7a8354d994" />
- Change your IPv4 on vmnet4 (the default IP is 10.10.10.1) to 10.10.10.20
-  <img width="935" height="558" alt="image" src="https://github.com/user-attachments/assets/f5195f95-5aa5-4991-aa8f-00fec95522a8" />


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
 > **⚠️ Notice:** Remember to take snapshot of the this router because it will not auto save current state into ROM
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
  - `ping -c 3 10.10.10.20`
  - <img width="611" height="185" alt="image" src="https://github.com/user-attachments/assets/4f915dbb-beec-4d1b-922d-2f0138cbc5e7" />
  - <img width="765" height="217" alt="image" src="https://github.com/user-attachments/assets/9df88f98-7a32-43b6-970a-698217f62fa6" />
  - The traceroute command stop at the ip of the router(10.10.50.1) because my firewall rule on ADMIN-PC only allow icmp and UDP/TCP on specified ports from 10.10.50.10 (Details in Step 2: Firewall configuration) 
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

### Attacker Kali (10.10.50.20/24)
#### Set static IP Address for attacker machine 

<img width="684" height="549" alt="image" src="https://github.com/user-attachments/assets/cce6163f-7a9c-4b90-89b1-b405db78b3dd" />

We have the `eth1` here need to set to statics IP Address. Run the command `sudo vim /etc/network/interfaces` and add the config for eth1: 
```
iface eth1 inet static
auto eth1
address 10.10.50.20/24
netmask 255.255.255.0
gateway 10.10.50.1
```
After that, run `sudo ifup eth1` to manually restart the adapter
<img width="651" height="515" alt="image" src="https://github.com/user-attachments/assets/db711ddc-e746-4e9a-ad93-627f089f98ff" />


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
#### Install iptables
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
  - Re-run `apk update` now you're able to install iptables (i think i should use something that i used to, instead of nftables :)))) : <img width="555" height="194" alt="image" src="https://github.com/user-attachments/assets/8c3f5367-81d2-41dd-9f95-5f4186adef24" />
#### firewall.sh
```bash
#delete all default rules
iptables -F
iptables -t nat -F
iptables -X

#set the firewall policy to deny-by-default
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

#Allow loopback and session has been established
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Allow SSH from Admin VLAN 10.10.10.0/24
iptables -A INPUT -i eth1 -p tcp --dport 22 -s 10.10.10.0/24 -j ACCEPT

#Allow ICMP (Ping) from 2 VLANs
iptables -A INPUT -p icmp -s 10.10.10.0/24 -j ACCEPT
iptables -A INPUT -p icmp -s 10.10.50.0/24 -j ACCEPT

# Enable NAT (for outbound Internet access)
iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE

# Allow forwarding from internal VLANs (eth0, eth1) to NAT (eth2)
iptables -A FORWARD -i eth0 -o eth2 -s 10.10.50.0/24 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -s 10.10.10.0/24 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#After this, you can remote NAT on each machine because now we can forward traffic to router -> NAT -> Internet.

#Allow forwarding between two VLANs
iptables -A FORWARD -i eth0 -o eth1 -s 10.10.50.0/24 -d 10.10.10.0/24 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -s 10.10.10.0/24 -d 10.10.50.0/24 -j ACCEPT

# Allow Honeypot <-> SIEM (log traffic)
iptables -A FORWARD -i eth0 -o eth1 -s 10.10.50.10 -d 10.10.10.20 -p udp --dport 514 -j ACCEPT   # Syslog
iptables -A FORWARD -i eth0 -o eth1 -s 10.10.50.10 -d 10.10.10.20 -p tcp --dport 5044 -j ACCEPT # Filebeat
iptables -A FORWARD -i eth1 -o eth0 -s 10.10.10.20 -d 10.10.50.10 -j ACCEPT                   # SIEM -> Honeypot

# Log and drop everything else
iptables -A INPUT -m limit --limit 3/min -j LOG --log-prefix "DROP-IN: "
iptables -A FORWARD -m limit --limit 3/min -j LOG --log-prefix "DROP-FWD: "
```
Create file `firewall.sh` on Admin PC (10.10.10.20) and run: `scp "C:\Users\anqul1\Desktop\firewall.sh" root@10.10.50.1:/root/` to tranfer the file to our router.  
<img width="904" height="441" alt="image" src="https://github.com/user-attachments/assets/c53a31d3-86f2-425a-b91b-3f4a9aecef8a" />
Now let's run the script:
```bash
chmod +x /root/firewall.sh
./firewall.sh
```
after i run scripts i got many errors, i ask GPT and it tells me that on Alpine distro it uses `iptables-nft`, so the classic command will not be compatible. Now let's re-install `iptables-legacy`:
```
#install iptables-legacy
apk del iptables
apk add iptables iptables-legacy
modprobe ip_tables
modprobe iptable_filter
modprobe iptable_nat
modprobe nf_conntrack
modprobe nf_conntrack_ipv4
#rerun script
./firewall.sh
```
<img width="1278" height="409" alt="image" src="https://github.com/user-attachments/assets/3be8ada6-d6f3-4b8e-9978-639dfa743a51" />

Now let's test ssh from admin to router:
<img width="917" height="379" alt="image" src="https://github.com/user-attachments/assets/adaa4444-aeda-4c9c-94fa-1966b1476332" /> 
Success!
Ping from honeypot <-> Admin (10.10.10.20):
<img width="861" height="259" alt="image" src="https://github.com/user-attachments/assets/e41f1665-ac0b-4a83-8913-8a226b63f750" />
Ping from attacker <-> Admin (10.10.10.20):
<img width="545" height="133" alt="image" src="https://github.com/user-attachments/assets/731774d9-a5b5-4099-a12c-d73efc11b8ef" />

Test logging on the router: 
<img width="1462" height="590" alt="image" src="https://github.com/user-attachments/assets/c2be6ebb-3f0f-424a-91ae-84d293708308" />

 




