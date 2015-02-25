+++
date = "2015-02-25T18:14:00+00:00"
draft = false
title = "Running Go programs on $15 device - Beyond Hello World"
tag = ["go", "golang", "openwrt", "mips", "WT1520"]
+++

I recently purchased a [WT1520](http://wiki.openwrt.org/toh/nexx/wt1520) router for $15 from Aliexpress to play with. I have a project in mind which would require few nodes running my custom Go code spread out throughout the world. A Raspberry Pi (almost $40 if you include SD card, etc) fits perfectly for my purpose, but I am looking to be cheap. Not to be dissing on the pi, its awesome and LOT more powerful than the WT1520, I'm just trying to find the cheapest device for my purpose.
<figure>
	<img src="/images/wt1520-raspi.jpg" alt="Raspberry Pi and WT1520 doing the same thing" title="Raspberry Pi and WT1520 doing the same thing" \>
	<figcaption>Raspberry Pi ($35+) and WT1520 ($15 shipped) doing the same thing</figcaption>
</figure>
Having no experience with OpenWrt, this [blog post](http://akagi201.org/blog/golang-on-openwrt/) (sidenote: our blogs look similar) helped a lot to get Hello World running.

My Build Steps
--------------

I couldn't use the [gccgo fork](https://github.com/GeertJohan/openwrt-go) directly because support for my architecture was added at a later stage, so I had to clone the upstream master and patch it.

{{% highlight bash %}}
```
$ git clone git://git.openwrt.org/openwrt.git
$ cd openwrt
$ curl https://github.com/GeertJohan/openwrt-go/compare/add-gccgo-and-libgo.diff | patch -p1
$ make menuconfig
$ make -j8
```
{{% /highlight %}}

My resulting config : https://gist.github.com/sajal/f509183ac691a32e6065
Ive removed usb and wifi related things to keep the image small. It seems eglibc uses lot more space.

This builds gccgo 4.8.3 (Go 1.1.2 implementation). gcc 4.9.x is also available in menuconfig but [build fails](https://dev.openwrt.org/ticket/18611). Even then Go 1.2 is still ancient.

Building hello world is simple

{{% highlight bash %}}
```
$ export PATH=/home/sajal/src/openwrt/staging_dir/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_eglibc-2.19/bin:$PATH
$ alias gccgo='mipsel-openwrt-linux-gccgo -Wl,-R,/home/sajal/src/openwrt/staging_dir/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_eglibc-2.19/lib/gcc/mipsel-openwrt-linux-gnu/4.8.3 -L /home/sajal/src/openwrt/staging_dir/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_eglibc-2.19/lib'
$ gccgo -o hello ~/hello.go -static-libgo
```
{{% /highlight %}}

^ resulting in 2.6 MB binary...

So far so good... But my real code is not so simple. It is a file with main, which imports another package which imports another package.

In the following example, the project in question is a very rough draft, and the code is not public at the moment. Sorry.

I have a file called minion.go which id like to build.

Lets try to build it the same way as before.

```
$ gccgo -o minion minion.go -static-libgo
minion.go:9:38: error: import file 'github.com/turbobytes/dnsdebug/utils' not found
  "github.com/turbobytes/dnsdebug/utils"
                                      ^
minion.go:93:18: error: reference to undefined name 'dnsdebug'
  resolver := new(dnsdebug.Resolver)
                  ^
minion.go:93:26: error: expected type
  resolver := new(dnsdebug.Resolver)
                          ^
minion.go:101:10: error: reference to undefined name 'dnsdebug'
   cfg := dnsdebug.GetTLSConfig(caFile, certificateFile, privateKeyFile)
          ^
$ 
```

Hmm. gccgo does not resolve packages, and we cant make the Go provided toolchain to build using our MIPS gccgo... so lets see what the Go toolchain does when using normal gccgo.

<pre style="overflow-x:scroll;overflow-wrap: normal;white-space: pre;">
sajal@sajal-lappy:~/go/src/github.com/turbobytes/dnsdebug$ go build -x -compiler=gccgo minion.go 
WORK=/tmp/go-build071420589
mkdir -p $WORK/github.com/miekg/dns/_obj/
mkdir -p $WORK/github.com/miekg/
cd /home/sajal/go/src/github.com/miekg/dns
gccgo -I $WORK -c -g -m64 -fgo-pkgpath=github.com/miekg/dns -fgo-relative-import-path=_/home/sajal/go/src/github.com/miekg/dns -o $WORK/github.com/miekg/dns/_obj/dns.o ./client.go ./clientconfig.go ./defaults.go ./dns.go ./dnssec.go ./edns.go ./format.go ./keygen.go ./kscan.go ./labels.go ./msg.go ./nsecx.go ./privaterr.go ./rawmsg.go ./scanner.go ./server.go ./sig0.go ./singleinflight.go ./tlsa.go ./tsig.go ./types.go ./udp.go ./udp_linux.go ./update.go ./xfr.go ./zgenerate.go ./zscan.go ./zscan_rr.go
ar cru $WORK/github.com/miekg/libdns.a $WORK/github.com/miekg/dns/_obj/dns.o
mkdir -p $WORK/github.com/turbobytes/dnsdebug/utils/_obj/
mkdir -p $WORK/github.com/turbobytes/dnsdebug/
cd /home/sajal/go/src/github.com/turbobytes/dnsdebug/utils
gccgo -I $WORK -I /home/sajal/go/pkg/gccgo_linux_amd64 -c -g -m64 -fgo-pkgpath=github.com/turbobytes/dnsdebug/utils -fgo-relative-import-path=_/home/sajal/go/src/github.com/turbobytes/dnsdebug/utils -o $WORK/github.com/turbobytes/dnsdebug/utils/_obj/dnsdebug.o ./rpc.go ./tls.go
ar cru $WORK/github.com/turbobytes/dnsdebug/libutils.a $WORK/github.com/turbobytes/dnsdebug/utils/_obj/dnsdebug.o
mkdir -p $WORK/command-line-arguments/_obj/
cd /home/sajal/go/src/github.com/turbobytes/dnsdebug
gccgo -I $WORK -I /home/sajal/go/pkg/gccgo_linux_amd64 -c -g -m64 -fgo-relative-import-path=_/home/sajal/go/src/github.com/turbobytes/dnsdebug -o $WORK/command-line-arguments/_obj/main.o ./minion.go
ar cru $WORK/libcommand-line-arguments.a $WORK/command-line-arguments/_obj/main.o
cd .
gccgo -o minion $WORK/command-line-arguments/_obj/main.o -Wl,-( -m64 $WORK/github.com/turbobytes/dnsdebug/libutils.a $WORK/github.com/miekg/libdns.a -lpthread -Wl,-E -Wl,-)
sajal@sajal-lappy:~/go/src/github.com/turbobytes/dnsdebug$
</pre>

Using the hints from there... This is what I translated it to after a lot of trial and error.

<pre style="overflow-x:scroll;overflow-wrap: normal;white-space: pre;">
WORK=`mktemp -d`
mkdir -p $WORK/obj
mkdir -p $WORK/github.com/miekg/
cd /home/sajal/go/src/github.com/miekg/dns
gccgo -I $WORK -c -g -fgo-pkgpath=github.com/miekg/dns -fgo-relative-import-path=_/home/sajal/go/src/github.com/miekg/dns -o $WORK/obj/dns.o ./client.go ./clientconfig.go ./defaults.go ./dns.go ./dnssec.go ./edns.go ./format.go ./keygen.go ./kscan.go ./labels.go ./msg.go ./nsecx.go ./privaterr.go ./rawmsg.go ./scanner.go ./server.go ./singleinflight.go ./tlsa.go ./tsig.go ./types.go ./udp.go ./udp_linux.go ./update.go ./xfr.go ./zgenerate.go ./zscan.go ./zscan_rr.go
mipsel-openwrt-linux-gnu-objcopy -j .go_export $WORK/obj/dns.o $WORK/github.com/miekg/dns.gox
mkdir -p $WORK/github.com/turbobytes/dnsdebug/
cd /home/sajal/go/src/github.com/turbobytes/dnsdebug/utils
gccgo -I $WORK  -c -g -fgo-pkgpath=github.com/turbobytes/dnsdebug/utils -fgo-relative-import-path=_/home/sajal/go/src/github.com/turbobytes/dnsdebug/utils -o $WORK/obj/dnsdebug.o ./rpc.go ./tls.go
mipsel-openwrt-linux-gnu-objcopy -j .go_export $WORK/obj/dnsdebug.o $WORK/github.com/turbobytes/dnsdebug/utils.gox
cd /home/sajal/go/src/github.com/turbobytes/dnsdebug
gccgo -I $WORK  -c -g  -o $WORK/obj/minion.o ./minion.go
gccgo -o minion $WORK/obj/minion.o $WORK/obj/dns.o $WORK/obj/dnsdebug.o -static-libgo
</pre>

It took me a while to figure out that I needed to export the .gox files to be able to build code that depended on other packages.

Note: I had to adjust code a bit to support the ancient Go implementation... Specifically the TLS implementation and cipher suits.

{{% highlight bash %}}
```
$ file minion
minion: ELF 32-bit LSB  executable, MIPS, MIPS32 rel2 version 1, dynamically linked (uses shared libs), for GNU/Linux 2.6.16, not stripped
$ ls -lh minion
-rwxrwxr-x 1 sajal sajal 9.3M Feb 26 00:25 minion
```
{{% /highlight %}}

OpenWrt creates a 14MB tempfs, so this barely fits into /tmp of the WT1520, but works as expected. Striping it makes it unusable... The binary is too big to persist on the device, but it could be programmed to download binary fresh from some server on reboot. Not entirely sure I'd use this approach for production.

I think this is the cheapest off the shelf device that a Go program can run on productively.

Dear Gophers: Please implement MIPS architecture within the gc toolchain so that I can build apps for these cheap devices as easily as for ARM.

Next up, I will try to get my hands on [pogoplug](http://wiki.openwrt.org/toh/cloudengines/pogo-v4) . Amazon [has it](http://www.amazon.com/Pogoplug-Backup-and-Sharing-Device/dp/B005GM1Q1O/ref=sr_1_1?ie=UTF8&qid=1424886725&sr=8-1&keywords=pogoplug+mobile) for $13.69, but after including shipping and taxes it comes out to $51.30. And it doesn't seem to be something that will always be readily available at such low prices.