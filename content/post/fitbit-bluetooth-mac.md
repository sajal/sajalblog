+++
date = "2016-09-24T15:30:00+00:00"
draft = false
title = "Figuring out MAC address of a fitbit tracker"
tag = ["fitbit", "bluetooth", "presence", "go"]
+++

[Last week I posted](/post/presence-bluetooth.html) about potentially using my fitbit Charge HR for presence, and was looking for some way to figure out its MAC address. Here are some ways to do it.

#### BLE scan

First make sure the tracker is not connected to your phone. The simplest way is to turn off bluetooth on the phone (or force-close the fitbit app). Once this is done, the tracker not connected to any host app, starts advertising using bluetooth low energy.

Then from some linux host with BLE enabled adapter (in my case raspberry pi 3 ) run a `lescan`.

{{% highlight bash %}}
````
pi@raspberrypi:~$ sudo hcitool lescan
LE Scan ...
xx:xx:xx:xx:xx:xx (unknown)
yy:yy:yy:yy:yy:yy (unknown)
12:34:56:78:9A:BC (unknown)
12:34:56:78:9A:BC Charge HR
^Cpi@raspberrypi:~$ 
````
{{% /highlight %}}

Since there is only 1 Charge HR detected, I can be fairly confident that `12:34:56:78:9A:BC` belongs to me.

#### Syncing using Galileo

[Galileo](https://bitbucket.org/benallard/galileo/) is project that allows you to sync your tracker using the bundled dongle that comes with fitbit. It's python and useful if you use linux since fitbit does not provide software for it.

{{% highlight bash %}}
````
sajal@sajal-lappy:~/path/to/galileo$ ./run --fitbit-server client.fitbit.com --force -v
2016-09-24 22:07:11,549:INFO: Disconnecting from any connected trackers
2016-09-24 22:07:13,555:INFO: Got an I/O Timeout (> 2000ms) while reading!
2016-09-24 22:07:13,559:INFO: Discovering trackers to synchronize
2016-09-24 22:07:13,565:INFO: Ignoring message: StartDiscovery
2016-09-24 22:07:17,569:INFO: 1 trackers discovered
2016-09-24 22:07:17,569:INFO: Attempting to synchronize tracker BC9A78563412
2016-09-24 22:07:17,575:INFO: Starting new HTTPS connection (1): client.fitbit.com
2016-09-24 22:07:24,401:INFO: Getting data from tracker
2016-09-24 22:07:25,752:INFO: Sending tracker data to Fitbit
2016-09-24 22:07:25,753:INFO: Starting new HTTPS connection (1): client.fitbit.com
2016-09-24 22:07:27,165:INFO: Successfully sent tracker data to Fitbit
2016-09-24 22:07:27,165:INFO: Passing Fitbit response to tracker
Tracker: BC9A78563412: Synchronisation successful
````
{{% /highlight %}}

Note how `12:34:56:78:9A:BC` turns into `BC9A78563412`. The bytes are reversed.

#### Using Fitbit API

Fetch the list of devices associated to your account using the [Fitbit devices API](https://dev.fitbit.com/docs/devices/).

`GET https://api.fitbit.com/1/user/-/devices.json`

{{% highlight json %}}
````
[
  {
    "battery": "High",
    "deviceVersion": "Charge HR",
    "features": [
      
    ],
    "id": "xxxxxxxxx",
    "lastSyncTime": "2016-09-24T22:07:26.000",
    "mac": "BC9A78563412",
    "type": "TRACKER"
  }
]
````
{{% /highlight %}}

This again shows the reversed-byte MAC address in the `mac` field.

I have updated my [presence script](/post/presence-bluetooth.html#toc_1) to continuously run `hcitool lescan` and keep a map of devices available. This way if for some reason my phone's bluetooth drops out, I can keep track of myself using the Charge HR since it restarts advertisements once its link to the phone is broken.

#### Presence server upgrade

{{% highlight go %}}
````
package main

import (
	"flag"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"sync"
	"time"
)

var (
	blereg  = make(map[string]time.Time)
	blesync = &sync.RWMutex{}
)

func updateble() {
	log.Println("updating ble table")
	cmd := exec.Command("timeout", "--signal", "SIGINT", "5", "hcitool", "lescan")
	b, _ := cmd.Output()
	blesync.Lock()
	defer blesync.Unlock()
	for _, s := range strings.Split(string(b), "\n") {
		sp := strings.Split(s, " ")
		if len(sp) > 1 {
			log.Println(sp[0])
			blereg[sp[0]] = time.Now()
		}
	}
}

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
	go func() {
		for {
			updateble()
			time.Sleep(time.Second * 10)
		}
	}()
	flag.Parse()
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		mac := strings.Split(r.URL.Path, "/")[1]
		if mac == "" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		//Check blereg
		blesync.RLock()
		dur := time.Since(blereg[mac])
		blesync.RUnlock()
		log.Println(dur)
		if dur < time.Minute {
			//BLE registry saw this mac within last minute
			w.WriteHeader(http.StatusNoContent)
			return
		}
		if l2ping(mac) {
			w.WriteHeader(http.StatusNoContent)
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

This runs `hcitool lescan` in a loop making note of MACs discovered. When receiving a query it checks if the MAC was seen recently, if not then it tries to ping it on bluetooth classic. I could have use the [gatt](https://godoc.org/github.com/paypal/gatt) library to continuously scan over BLE, but on initializing gatt, it takes over the HCI device completely making me unable to run the l2ping command. gatt does not have the capability to do Bluetooth stuff.