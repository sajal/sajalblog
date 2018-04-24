+++
date = "2018-04-21T17:46:45+00:00"
draft = false
title = "Using Cloudflare's 1.1.1.1 might lead to slower CDN performance"
tag = ["cloudflare", "1dot1dot1dot1", "dns", "cdn", "site performance"]
+++

**Disclaimer: All views expressed here are personal**

Recently Cloudflare launched their [1.1.1.1](https://1.1.1.1/) public resolver in partnership with APNIC to great fan-fare boasting  performance improvements and increased privacy.

While their claims are true, I would like to talk about them [not forwarding](https://developers.cloudflare.com/1.1.1.1/nitty-gritty-details/#edns-client-subnet) [EDNS client subnet](https://tools.ietf.org/html/rfc7871)(ECS). [Quad9](https://www.quad9.net/) does something similar, but provide an [ECS capable IP](https://www.quad9.net/faq/#Is_there_a_service_that_Quad9_offers_that_does_not_have_the_blocklist_or_other_security) hidden in the docs for users who really care about performance.

In 2010 I [wrote a post](/in-a-cdnd-world-opendns-is-the-enemy.html) outlining how using public DNS resolvers leads to degraded performance when accessing non-anycast CDNs. We have come a long way since then, with EDNS Client Subnet being supported by most public resolvers, and a wider pop footprint, that blogpost is very outdated.

According to Cloudflare

> 1.1.1.1 is a privacy centric resolver so it does not send any client IP information and does not send the EDNS Client Subnet Header to authoritative servers

If I do a DNS lookup for `cdn.example.com`, it is with the intent of connecting to that website(over HTTP/HTTPS/TCP/whatever). The concern appears to be the CDN's authoritative DNS service provider being able to see the subnet of the end user. Sure that is one way some information about the user could *leak*. But /24 is not a strong indicator to identify specific user.

When I do make the final connection, I am sending my whole /32 IP address. The /24 (or /28) that would have been sent is hardly any privacy concern compared to the exact IP that's needed to be exposed while making a TCP connection.

While visiting a typical website, A user exposes their full IP to potentially following parties

1. The website's server
2. The website's loadbalancer (if any - Like AWS ELB, digital ocean, etc)
3. The website's hosting provider (AWS, DO, Google, etc etc...)
4. 1 - 3 for all 3rd party objects on the webpage (including their CDNs).
5. All network devices sitting in between 1 - 4

Authoritative DNS service provider is just another piece of a website's hosting infrastructure, which with ECS only gets partial IP. Sending partial IP, IMHO, is a very trivial privacy concern in comparison to the potential benefits.

For a non-anycast CDN, to get accurate DNS-based routing from user of 1.1.1.1, the following must work flawlessly.

1. Internal POP IP of Cloudflare must be very accurate in geoip databases like MaxMind and friends.
2. The user must always be routed to closest Cloudflare POP. If for some reason the path is wrong, then along with slower Cloudflare, users will experience slower all-CDNs.

But... Doesn't Cloudflare have POPs [almost everywhere](https://www.cloudflare.com/network/)?

Yes. But that only gives somewhat geographical granularity. What about ISP-level optimizations. I would like to only send users on Verizon from San Francisco to my Verizon POP. If that user uses 1.1.1.1, they don't benefit from all the money I spent in setting up that POP. If another CDN has more locations than Cloudflare, then for a 1.1.1.1 user the CDN has to limit their service based on Cloudflare's network map. CDNs who host closer to the Edge are impacted more than ones who host at hubs.

Some tests using [dnsperfbench](https://github.com/turbobytes/dnsperfbench) tool's [httptest](https://github.com/turbobytes/dnsperfbench/blob/httptest/README.md#httptest) feature. Basically for each resolver it figures out what IP the resolver is returning for Akamai, and then running HTTPS tests over it.

Choosing Akamai as the target of this test was an intentional selection bias on my end to highlight the issue at hand.

From Thailand/[AIS Fiber](https://www.ais.co.th/fibre/en/) (first hop adds ~20ms latency!)

```
$ dnsperfbench -resolver 115.178.58.10 -httptest https://turbobytes.akamaized.net/static/rum/100kb-image.jpg
2018/04/21 20:09:47 Resolving
2018/04/21 20:10:00 Issuing HTTP(s) tests
```

|              RESOLVER               |       REMOTE        |  DNS  | CONNECT |  TLS  | TTFB  | TRANSFER | TOTAL  |
|-------------------------------------|---------------------|------:|--------:|------:|------:|---------:|-------:|
| `115.178.58.10` (Unknown)             | 49.231.112.9:443    | 26ms  | 23ms    | 83ms  | 25ms  | 40ms     | 197ms  |
| `9.9.9.9` (Quad9)                     | 202.183.253.10:443  | 56ms  | 25ms    | 89ms  | 26ms  | 43ms     | 238ms  |
| `208.67.222.222` (OpenDNS)            | 49.231.112.33:443   | 71ms  | 23ms    | 83ms  | 25ms  | 40ms     | 242ms  |
| `8.8.8.8` (Google)                    | 49.231.112.9:443    | 110ms | 24ms    | 84ms  | 24ms  | 40ms     | 281ms  |
| `[2001:4860:4860::8888]` (Google)     | 49.231.112.33:443   | 111ms | 24ms    | 83ms  | 24ms  | 41ms     | 282ms  |
| `[2620:0:ccc::2]` (OpenDNS)           | 49.231.112.33:443   | 156ms | 24ms    | 82ms  | 24ms  | 40ms     | 326ms  |
| `[2606:4700:4700::1111]` (Cloudflare) | **23.49.60.192:443**    | 53ms  | 53ms    | 114ms | 53ms  | 69ms     | **342ms**  |
| `1.1.1.1` (Cloudflare)                | **23.49.60.192:443**    | 54ms  | 56ms    | 120ms | 57ms  | 72ms     | **358ms**  |
| `199.85.126.20` (Norton)              | 23.52.171.99:443    | 89ms  | 62ms    | 130ms | 60ms  | 85ms     | 426ms  |
| `180.76.76.76` (Baidu)                | 23.2.16.27:443      | 129ms | 86ms    | 180ms | 86ms  | 123ms    | 605ms  |
| `[2620:fe::fe]` (Quad9)               | 23.215.102.26:443   | 27ms  | 223ms   | 456ms | 224ms | 317ms    | 1.247s |
| `[2a0d:2a00:1::]` (Clean Browsing)    | 23.219.38.67:443    | 350ms | 228ms   | 465ms | 229ms | 278ms    | 1.55s  |
| `185.228.168.168` (Clean Browsing)    | 23.219.38.48:443    | 382ms | 227ms   | 463ms | 227ms | 292ms    | 1.591s |
| `119.29.29.29` (DNSPod)               | 205.197.140.136:443 | 474ms | 236ms   | 481ms | 244ms | 335ms    | 1.772s |
| `114.114.114.114` (114dns)            | 23.215.104.203:443  | 382ms | 283ms   | 573ms | 284ms | 401ms    | 1.924s |
| `8.26.56.26` (Comodo)                 | 104.86.110.154:443  | 219ms | 280ms   | 566ms | 279ms | 648ms    | 1.993s |


The fastest responding IP `49.231.112.x` is hosted inside my ISP, next best is in another ISP in Thailand. If I were to use `1.1.1.1` my access to things hosted with Akamai would get about 2x slower, in exchange for Akamai not getting to see my (partial) IP during DNS resolution.

Sure, Cloudflare's DNS service (which appears to be serving locally within this ISP) is new, perhaps Akamai has not updated their geoip databases with Cloudflare's backend IPs, perhaps Cloudflare has not yet published them, but even with that fix, the best Akamai could do is send me to a *generic* Thailand POP, instead of the one sitting at my ISP.

Similarly for Thailand/[True](http://www.trueinternet.co.th/ENG/index.html)

|              RESOLVER               |       REMOTE       |  DNS  | CONNECT |  TLS  | TTFB  | TRANSFER | TOTAL  |
|-------------------------------------|--------------------|------:|--------:|------:|------:|---------:|-------:|
| `203.144.206.49` (Unknown)            | 61.91.165.154:443  | 15ms  | 10ms    | 29ms  | 10ms  | 15ms     | 80ms   |
| `9.9.9.9` (Quad9)                     | 202.183.253.8:443  | 13ms  | 11ms    | 57ms  | 12ms  | 16ms     | 109ms  |
| `8.8.8.8` (Google)                    | 61.91.165.154:443  | 97ms  | 10ms    | 29ms  | 11ms  | 17ms     | 163ms  |
| `208.67.222.222` (OpenDNS)            | 61.91.165.154:443  | 105ms | 9ms     | 29ms  | 11ms  | 15ms     | 169ms  |
| `199.85.126.20` (Norton)              | 203.116.50.51:443  | 66ms  | 43ms    | 105ms | 43ms  | 46ms     | 303ms  |
| `1.1.1.1` (Cloudflare)                | **184.86.250.8:443**   | 36ms  | 67ms    | 144ms | 66ms  | 110ms    | **423ms**  |
| `180.76.76.76` (Baidu)                | 23.2.16.32:443     | 72ms  | 84ms    | 181ms | 84ms  | 114ms    | 535ms  |
| `119.29.29.29` (DNSPod)               | 23.42.156.42:443   | 70ms  | 90ms    | 187ms | 90ms  | 103ms    | 542ms  |
| `8.26.56.26` (Comodo)                 | 104.86.110.185:443 | 225ms | 220ms   | 442ms | 221ms | 312ms    | 1.421s |
| `185.228.168.168` (Clean Browsing)    | 80.239.137.26:443  | 212ms | 225ms   | 464ms | 229ms | 507ms    | 1.636s |
| `114.114.114.114` (114dns)            | 23.215.104.225:443 | 264ms | 259ms   | 527ms | 260ms | 610ms    | 1.92s  |

In this case only Google, OpenDNS and ISP resolvers send me to an ISP-local POP. Quad9 came #2 because of their fast DNS time (this test does not use locally cached DNS).

Cloudflare sends me to Singapore, and others further out.

Cloudflare sending me Singapore IP might be due to the fact that for me `1.1.1.1` is being routed to Cloudflare Singapore, probably True's fault.

<pre style="overflow-x:scroll;font-size:12px;white-space:pre">
~# mtr --report-wide 1.1.1.1
Start: Sat Apr 21 21:05:43 2018
HOST: apu                                       Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- 192.168.2.1                                0.0%    10    1.2   1.1   0.9   1.2   0.0
  2.|-- 10.137.128.1                               0.0%    10   18.0  13.4  10.5  18.8   2.8
  3.|-- 10.246.253.133                             0.0%    10    8.8   8.3   6.3   9.7   0.9
  4.|-- 10.185.94.203                              0.0%    10    8.2   9.3   7.8  11.7   1.3
  5.|-- 10.185.94.25                               0.0%    10    9.2   9.4   7.5  15.1   2.1
  6.|-- 61-91-220-101.static.asianet.co.th         0.0%    10    8.3   9.2   7.8  10.2   0.5
  7.|-- 58-97-82-116.static.asianet.co.th          0.0%    10    8.6  10.2   8.5  13.4   1.4
  8.|-- ppp-171-102-254-65.revip18.asianet.co.th   0.0%    10    9.2   9.7   8.3  11.4   0.7
  9.|-- ppp-171-102-254-227.revip18.asianet.co.th  0.0%    10   11.5  10.6   8.9  15.9   2.0
 10.|-- 210-86-143-74.static.asianet.co.th         0.0%    10    9.8   9.3   8.0  10.8   0.7
 11.|-- TIG-Net242-108.trueintergateway.com        0.0%    10   10.6  11.8   9.8  16.5   1.9
 12.|-- TIG-Net245-241.trueintergateway.com        0.0%    10   39.7  40.5  38.5  47.6   2.5
 13.|-- 13335.sgw.equinix.com                      0.0%    10   41.8  38.2  36.5  44.5   2.6
 14.|-- 1dot1dot1dot1.cloudflare-dns.com           0.0%    10   35.3  37.4  35.3  40.0   1.2
</pre>

Dear Cloudflare, please turn on ECS by default.

PS: Check out [ismydnsfast.com](https://ismydnsfast.com/) to check *your* performance to major authoritative DNS providers.
