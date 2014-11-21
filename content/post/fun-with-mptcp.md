+++
date = "2014-11-20T23:22:19+07:00"
draft = true
title = "Fun with MultiPath TCP"
tag = ["mptcp", "tcp", "network"]
+++

Over the last few months I've been playing with [MultiPath TCP](http://multipath-tcp.org/) and in this post I will show how I use it to leverage my humble [True ADSL](http://trueonline.truecorp.co.th/) line at home.

For performance and security reasons, I tunnel all my traffic thru a VPN. This is not necessarily to circumvent censorship, but to circumvent the [evil transparent proxies](http://www.sajalkayan.com/4-reasons-why-i-love-my-isp.html) my ISP puts in middle. The total bandwidth available is 10,600 kbps down / 1,200 kbps up.

Introduction to MultiPath TCP
-----------------------------

MultiPath TCP is an interesting effort to use multiple interfaces/networks for any single TCP connection. A Linux kernel implementation is being developed at [multipath-tcp.org](http://multipath-tcp.org/). Its main use cases are for mobile (transition between wifi and 3G) and datacenters. I exploit it to get better Internet browsing experience.

Old way
-------

<a href="/images/ssh_tun.svg"><img src="/images/ssh_tun.svg" alt="Simple SSH Tunnel" title="Simple SSH Tunnel" \></a>

1. SSH tunnel to EC2 instance in Singapore. Browser configured to use this tunnel as proxy
2. SSH tunnel to EC2 instance in us-east (for accessing geo-blocked services)

Main drawback : If my ISP has issues talking to AWS, then I'm totally screwed. This happened a month or so ago where most links coming into True was severely limited, however link from <a href="https://www.digitalocean.com/?refcode=f92c3276603e" rel="nofollow">Digital Ocean</a> to True was healthy. I had to manually change my tunnels to a $5 Digital Ocean instance.

New way
-------

<a href="/images/mptcp_tun.svg"><img src="/images/mptcp_tun.svg" alt="MPTCP Tunnel" title="MPTCP Tunnel" \></a>

Note: This is a constantly evolving setup as I find new things to play with.

Infrastructure involved :-

- <a href="http://www.pcengines.ch/apu.htm">PC Engines APU system board</a> - Replaces router. All magic happens here. *gateway*
- ADSL modem in bridge mode.
- EC2 instance in Singapore - The main proxy endpoint. Runs [shadowsocks](https://github.com/shadowsocks/shadowsocks-go) server over mptcp kernel. *destination 1, jumpbox 1*
- EC2 instance in us-west - The proxy endpoint for US geo blocked traffic. Runs shadowsocks server over mptcp kernel. *destination 2*
- Digital Ocean instance in Singapore - An alternate path to reach the EC2 instance(s) *jumpbox 2*
- VPS in [CAT](http://www.cattelecom.com/) datacenter in Thailand - Another alternate path. *jumpbox 3*
- Android phone - With Dtac 3G for extra boost when needed. USB tethering. Bandwidth fluctuates a lot. I typically use it to get a boost in my upload bandwidth which is generally 100 kbps to 2 mbps.

All tcp Traffic is intercepted by the APU using iptables, diverted to [redsocks](http://darkk.net.ru/redsocks/), which sends it to the shadowsocks client, which sends it to the shadowsocks server running in EC2 Singapore. This socks connection has several ways to communicate with the EC2 instance.

APU <--> True ADSL Directly <--> EC2  
APU <--> True ADSL Directly over OpenVPN/UDP <--> EC2  
APU <--> True ADSL <--> via CAT VPS over OpenVPN/UDP <--> EC2  
APU <--> True ADSL <--> via DO Singapore over OpenVPN/UDP <--> EC2  
APU <--> Dtac 3G Directly <--> EC2 (Optional/ondemand)

Now I have 5 possible paths. mptcp kernel creates a TCP connection over each available paths and bonds them together and exposes it as a single TCP connection to the application. Packets are sent over paths that currently have the lowest delay. Now my available bandwidth is not impacted by congestion over some of these paths. All paths need to be congested for me to have a bad day... Also some path might have good uplink, some might have good downlink, with mptcp you mix the best of both...

Example `bmon` stats when downloading a large file (I removed irreverent interfaces.)
<pre style="overflow-x:scroll;overflow-wrap: normal;white-space: pre;">
  #   Interface                RX Rate         RX #     TX Rate         TX #
─────────────────────────────────────────────────────────────────────────────
xxx (source: local)
  0   tun1                     621.28KiB        628      38.82KiB        636
  3   tun3                     200.22KiB        198       9.42KiB        149
  5   ppp0                       1.07MiB       1018     119.42KiB        980
  9   tun0                      90.06KiB         90       5.94KiB         97
</pre>

### Configurations

#### Jumpbox

Jumpbox is pretty basic setup. It's role is to provide additional gateways which mptcp uses to build additional paths.

OpenVPN server configured normally. Set to not redirect default gateway. In my current setup I need to ensure that the server assigns the same IP to my client. This is not really that crucial, but it keeps things simple. Its important to configure each jumpbox to use a different IP range.

`net.ipv4.ip_forward` needs to be set to 1 to allow forwarding. In fact almost all boxes in the setup need this.

iptables rules needed :-

	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	iptables -t filter -A FORWARD -i tun0 -j ACCEPT
	iptables -t filter -A FORWARD -o tun0 -j ACCEPT

Replace the `tun0` and `eth0` to suit your environment.

#### Destination

A destination server is remote end of our socks tunnel. It's job is to service the socks connections patching them to the real destination. 

This needs to run a [MultiPath TCP kernel](http://multipath-tcp.org/pmwiki.php/Users/HowToInstallMPTCP?). On EC2 it is pretty simple. Launch an Ubuntu 14.04 instance with a [pv-grub AKI](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/UserProvidedKernels.html). Then follow the [apt-repository installation method](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/UserProvidedKernels.html). And ensure the grub loads the mptcp kernel as its first choice.

Next we also need shadowsocks server running. [RTFM](https://github.com/shadowsocks/shadowsocks-go/blob/master/README.md) its pretty simple. Before using shadowsocks I was using a simple `ssh -D` tunnel, but I found it to be inefficient. Often times one large transfer would make all other TCP streams *stuck*. Perhaps this has something to do with the fact that with SSH everything is happening over a single TCP stream whereas shadowsocks makes a new socks connection dedicated to each TCP connection.

#### Gateway

The gateway is the most complicated component. All the magic happens here. A lot of services run here. I will not elaborate on some of them.

**dbcpd** - Assign LAN users with IP

**bind** - For DNS recursion. Since we tunnel most traffic to Singapore, I also set bind to send DNS queries thru OpenVPN.

**iptables** - I use iptables to do the NAT. NAT all UDP packets to OpenVPN. Send all outgoing TCP connections to redsocks. 

<pre style="overflow-x:scroll;overflow-wrap: normal;white-space: pre;">
# Generated by iptables-save v1.4.14 on Sat Nov 22 00:37:10 2014
*nat
:PREROUTING ACCEPT [378881:57485495]
:INPUT ACCEPT [210208:17266788]
:OUTPUT ACCEPT [4099955:310913862]
:POSTROUTING ACCEPT [3239510:252587265]
:REDSOCKS - [0:0]
-A PREROUTING -i br0 -p tcp -j REDSOCKS
-A PREROUTING -i br0 -j REDSOCKS
-A POSTROUTING -o tun1 -j MASQUERADE
-A POSTROUTING -o tun0 -j MASQUERADE
-A POSTROUTING -o tun2 -j MASQUERADE
-A POSTROUTING -o eth0 -j MASQUERADE
-A REDSOCKS -d 0.0.0.0/8 -j RETURN
-A REDSOCKS -d 10.0.0.0/8 -j RETURN
-A REDSOCKS -d 127.0.0.0/8 -j RETURN
-A REDSOCKS -d 169.254.0.0/16 -j RETURN
-A REDSOCKS -d 172.16.0.0/12 -j RETURN
-A REDSOCKS -d 192.168.0.0/16 -j RETURN
-A REDSOCKS -d 224.0.0.0/4 -j RETURN
-A REDSOCKS -d 240.0.0.0/4 -j RETURN
-A REDSOCKS -d a.b.c.d/32 -j RETURN
-A REDSOCKS -d e.f.g.h/32 -j RETURN
-A REDSOCKS -d i.j.k.l/32 -j RETURN
-A REDSOCKS -d m.n.o.p/32 -j RETURN
-A REDSOCKS -d q.r.s.t/32 -j RETURN
-A REDSOCKS -s 192.168.5.1/32 -j RETURN
-A REDSOCKS -s 192.168.5.1/32 -j RETURN
-A REDSOCKS -s 192.168.1.2/32 -j RETURN
-A REDSOCKS -s 192.168.5.32/27 -p tcp -j REDIRECT --to-ports 12345
COMMIT
# Completed on Sat Nov 22 00:37:10 2014
# Generated by iptables-save v1.4.14 on Sat Nov 22 00:37:10 2014
*filter
:INPUT ACCEPT [115657469:73738905421]
:FORWARD ACCEPT [64078:47442189]
:OUTPUT ACCEPT [122121802:63701527314]
-A FORWARD -i eth1 -j ACCEPT
-A FORWARD -o eth1 -j ACCEPT
-A FORWARD -i br0 -j ACCEPT
-A FORWARD -o br0 -j ACCEPT
-A FORWARD -i eth0 -j ACCEPT
-A FORWARD -o eth0 -j ACCEPT
COMMIT
# Completed on Sat Nov 22 00:37:10 2014
# Generated by iptables-save v1.4.14 on Sat Nov 22 00:37:10 2014
*mangle
:PREROUTING ACCEPT [118734314:74507536093]
:INPUT ACCEPT [115635709:73734306355]
:FORWARD ACCEPT [3100331:759352048]
:OUTPUT ACCEPT [122104929:63698976437]
:POSTROUTING ACCEPT [125198421:64456746251]
-A PREROUTING ! -d 192.168.5.0/24 -i br0 -j MARK --set-xmark 0x1/0xffffffff
-A PREROUTING -d 10.8.0.10/32 -i br0 -j MARK --set-xmark 0x3/0xffffffff
-A PREROUTING -d 192.168.10.1/32 -i br0 -j MARK --set-xmark 0x2/0xffffffff
COMMIT
# Completed on Sat Nov 22 00:37:10 2014
</pre>

Note: a.b.c.d, e.f.g.h, i.j.k.l, m.n.o.p and q.r.s.t are public internet ips that I don't want redsocks to intercept.

Interfaces

- br0 - LAN
- tun[0-3] - Various Jumpboxes. OpenVPN tunnels.

Also, each interface is maintains its own [routing tables](http://multipath-tcp.org/pmwiki.php/Users/ConfigureRouting) using if-up scripts. For example this is what gets executed when one of the tunnels comes alive.

{{% highlight bash %}}
```
#!/bin/sh
ip rule add from 10.8.0.20 table 2 || true
ip route add 10.8.0.0/24 dev tun0 scope link table 2 || true
ip route add default via 10.8.0.21 dev tun0 table 2 || true
ip rule add fwmark 3 table 2 || true
```
{{% /highlight %}}

The fwmark is added so if in future I want to pipe different traffic to go thru this interface I can set the corresponding iptables rule.

All local services are scoped to listen only on local interfaces to avoid random people connecting to local services.

**redsocks** - Accepts intercepted connections and pipes it off to shadowsocks client

**shadowsocks client** - sends all TCP connections to shadowsocks server running in EC2 Singapore.

**wvdial** - To dial the ADSL connection which is itself behind a [Carrier-grade NAT](http://en.wikipedia.org/wiki/Carrier-grade_NAT). Sometimes the connection stops working while pppd things its still connected. Am ugly CRON script to test the network and flip it if needed.

{{% highlight bash %}}
```
#!/bin/bash

IP=`/sbin/ip route | grep -v default | grep ppp0 | cut -d " " -f 1`
COUNT=`echo $IP | wc -l`

echo $IP $COUNT
if [ $COUNT -eq 1 ] 
then
  ping -c 10 $IP > /dev/null
  if [ $? -eq 0 ]
  then
    echo "ppp0 is up"
  else
    echo "ppp0 is down"
    kill -SIGHUP `pgrep pppd`
    beep -l 25
  fi
else
  echo "ppp0 not found?!?!?!?1"
fi
```
{{% /highlight %}}
The script above tries to ping the default gateway of the ppp0 interface to find out if it is really up. `SIGHUP` signals pppd to handup and redial. I don't bother maintaining the pid of pppd because currently I use ppp0 exclusively for the ADSL modem.

Missing parts
-------------

There are some issues I am having that I need to sort out work-around for.

- **Default connection unstable**. If the initial syn packet for ppp0 (my default interface) fails, then the connection cant be established. I need to look deeper into mptcp docs to figure out how to make it such that if the initial TCP connection setup fails on ppp0 then make it try tun0, tun1 and so on.
- **Connection fairness**. Sometimes if I am doing a big upload, everything else (like browsing websites) seems too slow. The upload is hogging all the available uplink, which is already too tiny. I have my suspicions on buffer bloat...
- **Higher uplink usage**. When downloading something, I see > 10% upload traffic corresponding to it. This is lot higher than a simple setup. I need to investigate deeper whats causing it. Perhaps mptcp or the socks setup or OpenVPN.

Future path enhancements
------------------------

More paths can be added to get better throughput.

- 3G dongles from various providers.
- The shitty wifi that your apartment/office provider gives.
- More ADSL/Cable connections from diverse providers with different backbones.

Conclusion
----------

MPTCP is a fantastic piece of technology. Hat-tip to everyone who contributed to it. The PC Engines ALU box is also awesome. Very powerful x86_64 box consuming very little electricity. 