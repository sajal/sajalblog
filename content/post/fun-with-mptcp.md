+++
date = "2014-11-20T23:22:19+07:00"
draft = true
title = "Fun with MultiPath TCP"
tag = ["mptcp", "tcp", "network"]
+++

Over the last few months I've been playing with [MultiPath TCP](http://multipath-tcp.org/) and in this post I will show how I use it to leverage my humble [True ADSL](http://trueonline.truecorp.co.th/) line at home.

For performance and security reasons, I tunnel all my traffic thru a VPN. This is not necessiarly to circumvent censorship, but to curcumvent the [evil transparent proxies](http://www.sajalkayan.com/4-reasons-why-i-love-my-isp.html) my ISP puts in middle. The total bandwidth available is xxxx kbps down / xxx kbps up.

TODO: Image

Introduction to MultiPath TCP
-----------------------------

MultiPath TCP is an interesting effort to use multiple interfaces/networks for any single TCP connection. A Linux kernel implementation is being developed at [multipath-tcp.org](http://multipath-tcp.org/). Its main use cases are for mobile (transition between wifi and 3G) and datacenters. I exploit it to get better internet browsing experience.

Old way
-------

TODO: Image

1. SSH tunnel to EC2 instance in Singapore. Browser configured to use this tunnel as proxy
2. SSH tunnel to EC2 instance in us-east (for accessing geo-blocked services)

Main drawback : If my ISP has issues talking to AWS, then im totally screwed. This happened a month or so ago where most links comming into True was severely limited, however link from <a href="https://www.digitalocean.com/?refcode=f92c3276603e" rel="nofollow">Digital Ocean</a> to True was healthy. I had to manually change my tunnels to a $5 Digital Ocean instance.

New way
-------

TODO: Image

Note: This is a constantly evolving setup as I find new things to play with.

Infrastructure involved :-

- <a href="http://www.pcengines.ch/apu.htm">PC Engines APU system board</a> - Replaces router. All magic happens here.
- ADSL modem in bridge mode.
- EC2 instance in Singapore - The main proxy endpoint. Runs [shadowsocks](https://github.com/shadowsocks/shadowsocks-go) server over mptcp kernel.
- EC2 instance in us-west - The proxy endpoint for US geo blocked traffic. Runs shadowsocks server over mptcp kernel.
- Digital Ocean instance in Singapore - An alternate path to reach the EC2 instance(s)
- VPS in [CAT](http://www.cattelecom.com/) datacenter in Thailand - Another alternate path.
- Android phone - With Dtac 3G for extra boost when needed. USB tethering. Bandwidth fluctuates a lot. I typically use it to get a boost in my upload bandwidth which is generally 100 kbps to 2 mbps.

All tcp Traffic is intercepted by the APU using iptables, diverted to [redsocks](http://darkk.net.ru/redsocks/), which sends it to the shadowsocks client, which sends it to the shadowsocks server running in EC2 Singapore. This socks connection has several ways to comminucate with the EC2 instance.

APU <--> True ADSL Directly <--> EC2  
APU <--> True ADSL Directly over OpenVPN/UDP <--> EC2  
APU <--> True ADSL <--> via CAT VPS over OpenVPN/UDP <--> EC2  
APU <--> True ADSL <--> via DO Singapore over OpenVPN/UDP <--> EC2  
APU <--> Dtac 3G Directly <--> EC2 (Optional/ondemand)

Now I have 4 possible paths. mptcp kernel creates a TCP connection over each available paths and bonds them together and exposes it as a single TCP connection to the application. Packets are sent over paths that currently have the lowest delay. Now my available bandwidth is not impacted by congession over some of these paths. All paths need to be congested for me to have a bad day...


Future path enhancements
------------------------

More paths can be added to get better throughput.

- 3G dongles from various providers.
- The shitty wifi that your appartment/office provider gives.
- More ADSL/Cable connections from diverse providers with different backbones.