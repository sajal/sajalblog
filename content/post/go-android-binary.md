+++
date = "2016-01-26T16:00:00+00:00"
draft = false
title = "Building binary executables for Android in Go"
tag = ["android", "go", "golang", "gomobile", "binary"]
+++

I have a use-case to run an *external* Go binary from within an Android app. By *external* i mean something that was not bundled inside the APK, but rather (in my case) downloaded from the Internet. The reason for not bundling in-APK is that I need to be able to auto-upgrade the binary without upgrading the APK. APK updates either require user-action or play store or root - all three are not possible for my use-case. I spent an entire day on the issue(android n00b here), which turned out to be a very simple <strike>problem</strike> solution.

First thing I tried was building normal `linux/arm` binaries that I use for normal arm devices.
{{% highlight bash %}}
```
sajal@sajal-lappy:~$ GOARCH="arm" go build /path/to/filewithmain.go
```
{{% /highlight %}}
The generated binary works in general... until you try to access the net... all socket communications are blocked. After trying few random things, I realized its due to me not using the NDK to build it... The binary needs to be built with `android/arm` target. [gomobile](https://godoc.org/golang.org/x/mobile/cmd/gomobile) to the rescue.

gomobile allows us to either [generate an `.aar` library or an `.apk`](http://www.sajalkayan.com/post/android-apps-golang.html), both are not applicable here. Solution - use the toolchain gomobile installed but compile code by hand. 

My compile command :-
```
sajal@sajal-lappy:~$ GOMOBILE="/home/sajal/go/pkg/gomobile" GOOS=android GOARCH=arm CC=$GOMOBILE/android-ndk-r10e/arm/bin/arm-linux-androideabi-gcc CXX=$GOMOBILE/android-ndk-r10e/arm/bin/arm-linux-androideabi-g++ CGO_ENABLED=1 GOARM=7 go build -p=8 -pkgdir=$GOMOBILE/pkg_android_arm -tags="" -ldflags="-extldflags=-pie" -o minion -x ~/go/src/github.com/turbobytes/pulse/minion.go
sajal@sajal-lappy:~$ file minion
minion: ELF 32-bit LSB  shared object, ARM, EABI5 version 1 (SYSV), dynamically linked (uses shared libs), not stripped
sajal@sajal-lappy:~$ ls -lh minion
-rwxr-xr-x 1 sajal sajal 9.3M Jan 26 16:52 minion
sajal@sajal-lappy:~$
```

It took me a while to figure out the `-ldflags="-extldflags=-pie"` portion, without it my phone complains about binary not being in [PIE format](https://en.wikipedia.org/wiki/Position-independent_code).

Now need to wait for `android/368` or `android/amd64` support in gomobile so I can play with it in the emulator instead of real device...

PS: I know what I am doing is probably an anti-pattern, but this is not a normal end user app. It would run on devices dedicated to this and I will sign and validate downloads.

PSS: I figured this out by mucking around with gomobile using the `-x` option.