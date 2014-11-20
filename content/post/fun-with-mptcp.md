+++
date = "2014-11-20T23:22:19+07:00"
draft = true
title = "Fun with MultiPath TCP"
tag = ["mptcp", "tcp", "network"]
+++

Over the last few months I've been playing with [MultiPath TCP](http://multipath-tcp.org/) and in this post I will show how I use it to leverage my humble [True ADSL](http://trueonline.truecorp.co.th/) line at home.

For performance and security reasons, I tunnel all my traffic thru a VPN. This is not necessarily to circumvent censorship, but to circumvent the [evil transparent proxies](http://www.sajalkayan.com/4-reasons-why-i-love-my-isp.html) my ISP puts in middle. The total bandwidth available is xxxx kbps down / xxx kbps up.

TODO: Image

Introduction to MultiPath TCP
-----------------------------

MultiPath TCP is an interesting effort to use multiple interfaces/networks for any single TCP connection. A Linux kernel implementation is being developed at [multipath-tcp.org](http://multipath-tcp.org/). Its main use cases are for mobile (transition between wifi and 3G) and datacenters. I exploit it to get better Internet browsing experience.

Old way
-------

TODO: Image

1. SSH tunnel to EC2 instance in Singapore. Browser configured to use this tunnel as proxy
2. SSH tunnel to EC2 instance in us-east (for accessing geo-blocked services)

Main drawback : If my ISP has issues talking to AWS, then I'm totally screwed. This happened a month or so ago where most links coming into True was severely limited, however link from <a href="https://www.digitalocean.com/?refcode=f92c3276603e" rel="nofollow">Digital Ocean</a> to True was healthy. I had to manually change my tunnels to a $5 Digital Ocean instance.

New way
-------

TODO: Image

Note: This is a constantly evolving setup as I find new things to play with.

Infrastructure involved :-

- <a href="http://www.pcengines.ch/apu.htm">PC Engines APU system board</a> - Replaces router. All magic happens here. *gateway*
- ADSL modem in bridge mode.
- EC2 instance in Singapore - The main proxy endpoint. Runs [shadowsocks](https://github.com/shadowsocks/shadowsocks-go) server over mptcp kernel. *destination 1, jumpbpx 1*
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

Now I have 5 possible paths. mptcp kernel creates a TCP connection over each available paths and bonds them together and exposes it as a single TCP connection to the application. Packets are sent over paths that currently have the lowest delay. Now my available bandwidth is not impacted by congestion over some of these paths. All paths need to be congested for me to have a bad day...

### Configurations

#### Jumpbox

Jumpbox is pretty basic setup. It's role is to provide additional gateways which mptcp uses to build additional paths.

OpenVPN server configured normally. Set to not redirect default gateway. In my current setup I need to ensure that the server assigns the same IP to my client. This is not really that crucial, but it keeps things simple. Its important to configure each jumpbox to use a different IP range.

`net.ipv4.ip_forward` needs to be set to 1 to allow forwarding. iptables rules needed :-

	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	iptables -t filter -A FORWARD -i tun0 -j ACCEPT
	iptables -t filter -A FORWARD -o tun0 -j ACCEPT

Replace the `tun0` and `eth0` to suit your environment.

#### Destination

A destination server is remote end of our socks tunnel. It's job is to service the socks connections patching them to the real destination. 

This needs to run a [MultiPath TCP kernel](http://multipath-tcp.org/pmwiki.php/Users/HowToInstallMPTCP?). On EC2 it is pretty simple. Launch an Ubuntu 14.04 instance with a [pv-grub AKI](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/UserProvidedKernels.html). Then follow the [apt-repository installation method](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/UserProvidedKernels.html). And ensure the grub loads the mptcp kernel as its first choice.

Next we also need shadowsocks server running. [RTFM](https://github.com/shadowsocks/shadowsocks-go/blob/master/README.md) its pretty simple.

#### Gateway

The gateway is the most complicated component. All the magic happens here.

TODO

Future path enhancements
------------------------

More paths can be added to get better throughput.

- 3G dongles from various providers.
- The shitty wifi that your apartment/office provider gives.
- More ADSL/Cable connections from diverse providers with different backbones.