+++
date = "2016-09-18T15:53:00+00:00"
draft = false
title = "Detecting presence using Bluetooth"
tag = ["home automation", "bluetooth", "presence", "go"]
+++

*How to programmatically detect whether I am at home or not?* - That's the problem I am currently trying to solve. In this post I will outline what methods I am using and what I have tried/considered.

I use this presence information to automatically switch off lights when I leave my home, and turn them on when I *return*. By *return* I mean when my state changes from *not-present* to *present*

#### Previous Solution (Wi-Fi)

For about a year, I used my phone being present on my Wi-Fi network as an indicator of my presence at home. This approach did not work well for me.

My router would assign a static IP to my phone using DHCP, and the result of a ping test would indicate my presence.

{{% highlight bash %}}
````
#!/bin/bash

ping -c 3 192.168.x.x > /dev/null
if [ $? -eq  0 ]; then
	#Sajal is at home...
else
	#Sajal is not at home...
fi
````
{{% /highlight %}}

I have set my phone to stay on Wi-Fi even if it thinks Internet connectivity is not available. In spite of this, the phone would occasionally disconnect from Wi-Fi (or fail the ping test). Often, when I am at home the lights would go off, and I would need to fiddle with my phone to get it back on Wi-Fi. Almost every morning I would wake up and realize my living room lights are turned on, at some point during the night my code thought I sleep-walked out of my home and returned.

Also, it would take anywhere between 0 to 100 seconds for the phone to get back onto Wi-Fi once I returned home. This is annoying at night, especially if I have my hands full with groceries.

I altered this a bit by using arp instead of ping.

{{% highlight bash %}}
````
#!/bin/bash

if [ $(arp -n | grep "xx:xx:xx:xx:xx:xx" | wc -l) -eq  1 ]; then
	#Sajal is at home...
else
	#Sajal is not at home...
fi
````
{{% /highlight %}}

This provides some relief from intermittent Wi-Fi issues because it takes time for arp cache to flush out the information, but most of the problems of the ping method are still applicable.

#### Current Solution

Currently I have a Raspberry Pi pinging my phone over Bluetooth to detect presence. All you need for this to work is your phone's Bluetooth MAC address. The phone does not need to be in detectable/scanning mode, just that Bluetooth should be turned on.

I was originally skeptical about using Bluetooth. I did not expect the signal to cover my entire (1-bedroom) apartment, but turns out it works very well. Now my lights turn on even before I am done opening my door.

I have the following Go code running on a Raspberry Pi 3 (which has Bluetooth builtin). 

{{% highlight go %}}
````
package main

import (
	"flag"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"time"
)

func l2ping(mac string) bool {
	log.Println("Checking ", mac)
	cmd := exec.Command("l2ping", "-c", "1", mac)
	err := cmd.Run()
	if err != nil {
		log.Println(err)
		return false
	}
	return true

}

func main() {
	var addr = flag.String("addr", ":8081", "address/port to listen on")
	flag.Parse()
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		mac := strings.Split(r.URL.Path, "/")[1]
		if mac == "" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if l2ping(mac) {
			//TODO: Use 204 not 200
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(http.StatusNotFound)
	})
	s := &http.Server{
		Addr:           *addr,
		ReadTimeout:    10 * time.Second,
		WriteTimeout:   10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	log.Fatal(s.ListenAndServe())
}
````
{{% /highlight %}}

I need to use this http API because the bash script runs on a device without Bluetooth support. My bash script evolved to call the Go code using curl.

{{% highlight bash %}}
````
#!/bin/bash

if [ $(curl --write-out %{http_code} --silent --output /dev/null http://192.168.x.x:8081/xx:xx:xx:xx:xx:xx) -eq 200 ]; then
	#Sajal is at home...
else
	#Sajal is not at home...
fi
````
{{% /highlight %}}

Figuring out my phone's Bluetooth MAC address was relatively straightforward.

1. Put your phone in detectable mode.
2. Scan available devices.
3. Test if it is pingable. Phone does not need to be detectable any more.

{{% highlight bash %}}
````
pi@raspberrypi:~$ hcitool scan
Scanning ...
	yy:yy:yy:yy:yy:yy	KDL-50W800C
	xx:xx:xx:xx:xx:xx	G4
pi@raspberrypi:~$ sudo l2ping -c 4 xx:xx:xx:xx:xx:xx
Ping: xx:xx:xx:xx:xx:xx from zz:zz:zz:zz:zz:zz (data size 44) ...
0 bytes from xx:xx:xx:xx:xx:xx id 0 time 5.90ms
0 bytes from xx:xx:xx:xx:xx:xx id 1 time 7.35ms
0 bytes from xx:xx:xx:xx:xx:xx id 2 time 28.66ms
0 bytes from xx:xx:xx:xx:xx:xx id 3 time 28.64ms
4 sent, 4 received, 0% loss
pi@raspberrypi:~$ 

````
{{% /highlight %}}

Apparently *KDL-50W800C* is a Sony TV, perhaps belonging to a neighbour, I can't ping it because it's probably too far. The *G4* is my phone.

This method has been in production for the last week, and only once did it give a false negative. My phone was running some upgrades and for some reason Bluetooth stopped working until I rebooted.

#### Whats next?

In order to make the presence detection more robust, I am considering the following **in addition** to the above...

1. Somehow detect the presence of my [Fitbit Charge HR tracker](https://www.fitbit.com/chargehr). I can't seem to figure out the MAC address of the tracker. If someone knows of a way let me know. Someone else [blogged about](http://dotnet.work/2016/02/tracking-fitbit-presence-under-linux-raspberry-pi-2/) using the bundled dongle for this, but it is very unreliable method. If the Fitbit is connected with the phone, [galileo](https://bitbucket.org/benallard/galileo/) will not be able to detect it.
2. Get a Bluetooth tag and attach to keychain. I see some commercially available tags (example [Tile](https://www.thetileapp.com/)), but these tags are meant to work with apps on phones. I don't know if works on regular computers with Bluetooth dongles (Raspberry Pi).
3. Motion sensors. These would obviously not work when I am asleep or still... But it's something to look into, especially since I plan to use it for bathroom lights. Motion sensors might give me some sense of which room I am in, should I need that information for future projects.
4. Keycard holders. The type they use in hotels as a master switch for the room. The difference is in my case I would only use it as a signal for presence and not hardwire my mains thru it. Could be a simple mechanical switch wired to GPIO pins of a pi.
5. Door sensors. Might have some other useful applications as well.

#### Discarded ideas

1. Timer based presence. Assume me to be present from some specified time to another specified time.
2. GPS+phone based presence solution. At home the GPS is very inaccurate. I would need to add a huge error margin(few hundred meters - or higher if its rain-ey), effectively my system would think I am at home even if I am only in the general vicinity.

#### UPDATE

I investigated more about the possibility of using my Fitbit Charge HR for presence. It is not a practical option. The pi can detect it, but if I open the Fitbit app on my phone, the Fitbit [will stop advertisingg](https://community.fitbit.com/t5/Web-API/Charge-HR-and-Bit-Finder-Geo-app/m-p/1106648#M4177) until I either force close the Fitbit app, or turn off (and on) the Bluetooth functionality on the phone.

{{% highlight bash %}}
````
pi@raspberrypi:~$ sudo timeout --signal SIGINT 5 hcitool lescan
LE Scan ...
xx:xx:xx:xx:xx:xx (unknown)
xx:xx:xx:xx:xx:xx Charge HR
yy:yy:yy:yy:yy:yy (unknown)
zz:zz:zz:zz:zz:zz (unknown)
pi@raspberrypi:~$ #Now open app on phone and sync
pi@raspberrypi:~$ sudo timeout --signal SIGINT 5 hcitool lescan
LE Scan ...
zz:zz:zz:zz:zz:zz (unknown)
yy:yy:yy:yy:yy:yy (unknown)
pi@raspberrypi:~$ 
````
{{% /highlight %}}