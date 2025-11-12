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