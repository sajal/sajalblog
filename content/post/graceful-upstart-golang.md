+++
date = "2016-04-02T12:46:11+00:00"
draft = true
title = "Graceful Go Services Using Upstart"
tag = ["graceful", "golang", "ubuntu", "upstart", "go"]
+++

I typically use [Upstart](http://upstart.ubuntu.com/) to deploy services written in Go. Most of these services are simple and stateless. They can be killed and restarted without any thought. However I am currently writing a distributed system that is very statefull. Each instance of the Go service runs one or more long running tasks (event stream processing), and maintain a state of the data. This state is constantly updated as new events come in for processing. The service regularly backups the state externally and when some other service resumes the job of a killed service, it downloads the previously backed-up state and resumes. 

The service maintains a distributed lock (in [etcd](https://coreos.com/etcd/) with timeout), and when gracefully shut down it dumps state and releases the lock so other instances can immediately pick up this job, with negligible downtime, however if the process is killed(for upgrade of binary or server shutdown), the state dump might not be fresh, and other instances need to wait for the lock in etcd to time out before they can pick it up. This causes the resumed job to have an older state and missing data.

A simplified example :-

{{% highlight go %}}
```
package main

import (
	"log"
	"os"
	"os/signal"
	"time"
)

func main() {
	//Simulating a long running task...
	log.Println("Starting...")
	c := make(chan os.Signal)
	//Register listener for SIGINT
	signal.Notify(c, os.Interrupt)
	sig := <-c
	log.Println("Signal:", sig)
	time.Sleep(time.Second * 5) //Simulating cleanup/release locks/etc...
	log.Println("Dying of natural causes...")
}

```
{{% /highlight %}}

If you run this program, only when using `SIGINT` (kill -INT or CTRL + C) will the cleanup trap be triggered.

To follow thru rest of this post, put the compiled Go code as `/usr/local/bin/graceful`

`go build -o graceful graceful.go && sudo mv graceful /usr/local/bin/graceful`

My usual upstart template is no good here...

/etc/init/graceful.conf
```
description "graceful example"
author "Me <me@example.com>"

start on runlevel [2345]
stop on runlevel [016]
respawn
console log
limit nofile 100000 100000
setuid nobody
setgid nogroup
exec /usr/local/bin/graceful 2>&1 | logger -t graceful
```
Obviously this does not give time for cleanup...
```
sajal@sajal-lappy:~$ sudo service graceful start
graceful start/running, process 950223
sajal@sajal-lappy:~$ sudo service graceful stop
graceful stop/waiting
sajal@sajal-lappy:~$ grep graceful /var/log/syslog
Apr  2 21:22:15 sajal-lappy graceful: 2016/04/02 21:22:15 Starting...
Apr  2 21:22:19 sajal-lappy kernel: [4134089.549794] init: graceful main process (950223) killed by TERM signal
```
The process got killed, not interrupted... Note PID 950223 belonged to the exec process and not our binary. This will be relevant below.

Fortunately for us, Upstart allows us to [specify the kill signal](http://upstart.ubuntu.com/cookbook/#kill-signal) being used... Lets update /etc/init/graceful.conf
```
description "graceful example"
author "Me <me@example.com>"

start on runlevel [2345]
stop on runlevel [016]
respawn
console log
limit nofile 100000 100000
setuid nobody
setgid nogroup
kill signal INT
exec /usr/local/bin/graceful 2>&1 | logger -t graceful
```

