#!/bin/bash

# Reset all rule -> default rule
iptables -F
iptables -t nat -F
iptables -X
# It's a honeypot so we need to set the rule to deny-by-default
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#Allow loopback and session has been established
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow incoming from attacker in VLAN to honeypot ports + ICMP
  # Cowrie (SSH giả)
  iptables -A INPUT -p tcp -s 10.10.50.0/24 --dport 2222 -j ACCEPT
  # Glastopf (HTTP)
  iptables -A INPUT -p tcp -s 10.10.50.0/24 --dport 8080 -j ACCEPT
  # Dionaea (SMB)
  iptables -A INPUT -p tcp -s 10.10.50.0/24 --dport 445 -j ACCEPT
  # allow ICMP (ping) from VLAN of the Honeypot (where the attacker located)
  iptables -A INPUT -p icmp -s 10.10.50.0/24 -j ACCEPT 
  # Allow ICMP (Ping) from the Honeypot to other in VLAN
  sudo iptables -A OUTPUT -p icmp -d 10.10.50.0/24 -j ACCEPT
# Allow incoming from Management (Admin/SIEM)
  # SSH từ Admin
    iptables -A INPUT -p tcp -s 10.10.10.20 --dport 22 -j ACCEPT
  # Filebeat -> Logstash (TCP/5044)
    iptables -A OUTPUT -p tcp -d 10.10.10.20 --dport 5044 -j ACCEPT
  # Syslog -> UDP/514
    iptables -A OUTPUT -p udp -d 10.10.10.20 --dport 514 -j ACCEPT
# On the NIC2 (ens37 - the NAT NIC)
  #ping internet
  iptables -A OUTPUT -p icmp --icmp-type echo-request -o ens37 -j ACCEPT
  # DNS (UDP/TCP) on NAT interface so name resolution works
  # DNS (UDP/TCP)
  iptables -A OUTPUT -o ens37 -p udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -o ens37 -p tcp --dport 53 -j ACCEPT
  # DHCP client (UDP/67)
  iptables -A OUTPUT -o ens37 -p udp --dport 67 -j ACCEPT
# TEMPORARY: allow HTTP/HTTPS on NAT for apt/docker pull 
  iptables -A OUTPUT -o ens37 -p tcp --dport 80 -j ACCEPT
  iptables -A OUTPUT -o ens37 -p tcp --dport 443 -j ACCEPT
#Show rules
  iptables -L -v -n