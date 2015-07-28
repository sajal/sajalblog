+++
date = "2015-07-28T15:50:09+00:00"
draft = false
title = "Writing Android apps with Go bindings"
tag = ["android", "go", "golang", "gomobile"]
+++

[tl;dr version](https://godoc.org/golang.org/x/mobile/cmd/gomobile)

One of the new features of upcoming Go 1.5 release is the awesome tooling around building Android (and iOS) apps using Go code.

Recently after playing with [Ivy](https://play.google.com/store/apps/details?id=org.golang.ivy) - an app made by Go mobile team - I wanted to give it a go (pun intended). Ivy is supposedly written in pure Go, unfortunately the source of it's mobile implementation is not open yet.

Since I don't know Java, my original goal was to try and make the whole app in Go, but thats not really possible. So I ended up using Java for UI and [here is the result](https://play.google.com/store/apps/details?id=com.turbobytes.dig). No iOS version yet because i don't own a mac.

First lets get our tooling in order... (Instructions for Ubuntu - adapt for your distro/OS)

I [downloaded](https://golang.org/dl/) and extracted `go1.5beta2` to /home/sajal/gobeta because I didnt want to mess up my existing 1.4.2 environment. 

Now install gomobile

{{% highlight bash %}}
```
export PATH=/home/sajal/gobeta/bin:$PATH
go get golang.org/x/mobile/cmd/gomobile
gomobile init  #This expects go 1.5 to be in PATH which we solved in the first step.
```
{{% /highlight %}}

Then I played with some example apps.

{{% highlight bash %}}
```
export PATH=/home/sajal/gobeta/bin:$PATH
cd $GOPATH/src/golang.org/x/mobile/example/basic/
gomobile build .
adb install basic.apk
```
{{% /highlight %}}

Works on mobile... the only problem is that [this](https://github.com/golang/mobile/blob/master/example/basic/main.go) is OpenGL stuff which I am totally clueless about.. So until the source of Ivy is released, I'd have to make the UI in Java...

First project DNS debugger. Much of the [Go code](https://github.com/turbobytes/pulse) was written for [TurboBytes Pulse](https://pulse.turbobytes.com/) already... Lets reuse this....

{{% highlight bash %}}
```
export PATH=/home/sajal/gobeta/bin:$PATH
$ ANDROID_HOME="/home/sajal/Android/Sdk/" gomobile bind github.com/turbobytes/pulse/utils
panic: unsupported seqType: interface{} / *types.Interface

goroutine 1 [running]:
golang.org/x/mobile/bind.seqType(0x7ff3da1cd498, 0xc8261c8e60, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/bind/seq.go:72 +0xaf8
golang.org/x/mobile/bind.(*goGen).genStruct(0xc82ab31730, 0xc8261ba7d0, 0xc8261c8dc0)
	/home/sajal/go/src/golang.org/x/mobile/bind/gengo.go:185 +0xfd4
golang.org/x/mobile/bind.(*goGen).gen(0xc82ab31730, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/bind/gengo.go:424 +0x98b
golang.org/x/mobile/bind.GenGo(0x7ff3da1cd220, 0xc82ab66338, 0xc82015f780, 0xc8201ea780, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/bind/bind.go:47 +0x195
main.(*binder).GenGo.func1(0x7ff3da1cd220, 0xc82ab66338, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/cmd/gomobile/bind.go:158 +0x4d
main.writeFile(0xc82ab88740, 0x35, 0xc82ab31910, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/cmd/gomobile/bind.go:211 +0x35b
main.(*binder).GenGo(0xc82ab6d8c0, 0xc8201526a0, 0x1c, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/cmd/gomobile/bind.go:160 +0x414
main.goAndroidBind(0xc820176000, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/cmd/gomobile/bind_androidapp.go:31 +0x12d
main.runBind(0xc8cba0, 0x0, 0x0)
	/home/sajal/go/src/golang.org/x/mobile/cmd/gomobile/bind.go:89 +0x26c
main.main()
	/home/sajal/go/src/golang.org/x/mobile/cmd/gomobile/main.go:63 +0x495

goroutine 17 [syscall, locked to thread]:
runtime.goexit()
	/home/sajal/gobeta/src/runtime/asm_amd64.s:1696 +0x1
sajal@sajal-lappy:/tmp$ 

```
{{% /highlight %}}

Woops... any package exporting interface{} (and uint16 which the dns library needs) types cant be used by gomobile bind ....FAIL

Solution: I wrote package [github.com/turbobytes/pulse/digdroid](https://github.com/turbobytes/pulse/blob/master/digdroid/digdroid.go) with a proxy function that returns a struct with only strings. No interfaces.

{{% highlight go %}}
```
package digdroid
type DNSResult struct {
	Err    string
	Output string
	Rtt    string
}

func RunDNS(host, target, qtypestr string, norec bool) *DNSResult
```
{{% /highlight %}}


{{% highlight bash %}}
```
$ ANDROID_HOME="/home/sajal/Android/Sdk/" gomobile bind  github.com/turbobytes/pulse/digdroid
$ ls -lh
total 2.8M
-rw-rw-r-- 1 sajal sajal 2.8M Jul 28 22:04 digdroid.aar
$ file digdroid.aar 
digdroid.aar: Zip archive data, at least v2.0 to extract
$ unzip -l digdroid.aar
Archive:  digdroid.aar
  Length      Date    Time    Name
---------  ---------- -----   ----
       99  1980-00-00 00:00   AndroidManifest.xml
       25  1980-00-00 00:00   proguard.txt
     9009  1980-00-00 00:00   classes.jar
  9395848  1980-00-00 00:00   jni/armeabi-v7a/libgojni.so
        0  1980-00-00 00:00   R.txt
        0  1980-00-00 00:00   res/
---------                     -------
  9404981                     6 files
$ 
```
{{% /highlight %}}

This results in creation of a file `digdroid.aar` which can be used as dependency in Android Studio. `jni/armeabi-v7a/libgojni.so` inside `digdroid.aar` is the actual Go library.

Next we move to Java territory.

I installed [Android Studio](http://developer.android.com/tools/studio/index.html), setup a new project, made basic UI and an Activity.

Include `digdroid.aar` into the project. Instructions from the [docs](https://godoc.org/golang.org/x/mobile/cmd/gomobile):-

> For example, in Android Studio (1.2+), an AAR file can be imported using the module import wizard (File > New > New Module > Import .JAR or .AAR package), and setting it as a new dependency (File > Project Structure > Dependencies). This requires 'javac' (version 1.7+) and Android SDK (API level 9 or newer) to build the library for Android. The environment variable ANDROID_HOME must be set to the path to Android SDK.

Once thats done, I could access the Go library from anywhere simply by importing `go.digdroid.Digdroid`

Example usage of above Go code from Java
{{% highlight java %}}
```
Digdroid.DNSResult result = Digdroid.RunDNS("www.example.com.", "8.8.8.8:53", "A", false);
String output = result.getOutput();
String rtt = result.getRtt();
String err = result.getErr();
```
{{% /highlight %}}

`gomobile bind` created the getters and setters for free...

One downside is `gomobile bind` only created binary for armv7. So the project no longer works on the emulator which is x86. But almost all android devices are arm, so its not really a big issue.

To update `digdroid.aar` simply build a new one and replace the `digdroid.aar` file within the Android Studio source tree.

One thing... For some reason the built apk was including extra permissions that I didn't really need. Solution declare those extra permissions in the manifest in a special manner so it gets removed when being built.

{{% highlight xml %}}
```
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="18"
    tools:node="remove"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE" tools:node="remove"/>
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="18"
    tools:node="remove"/>
```
{{% /highlight %}}

Since I added these with `tools:node="remove"` the builder will remove it from the apk. If I did not do that then the builder would add them into the final apk for some reason... Nobody asked for these permissions and they are not relevant to the code.

PS: I understand there is a cost associated with jumping language boundaries. This is just a fun little project. I am desperately waiting for some easier way to write apps completely in Go without bindings. I am even willing to dabble with QT stuff (or similar) if someone can show me how to build it in Go for mobile. Besides, for networked functions, few microseconds cost for jumping languages is negligible compared to the cost of making the actual network requests which can be 10s of milliseconds or more.

- Play store listing: https://play.google.com/store/apps/details?id=com.turbobytes.dig
- Android Project Source : https://github.com/sajal/digdroid
- Go package : http://godoc.org/github.com/turbobytes/pulse/digdroid
- Awesomest DNS library : https://github.com/miekg/dns
- TurboBytes Pulse : https://pulse.turbobytes.com/