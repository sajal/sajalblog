+++
date = "2016-02-06T13:00:00+00:00"
draft = true
title = "Sign web content using PGP"
tag = ["html", "pgp"]
+++

A lot of web-content these days passes thru untrusted intermediaries, especially plain text traffic which is often intercepted by ISP proxies for caching (and other purposes ;) ). A compromise at these places [can subject your users to malicious payload](http://www.telecomasia.net/content/true-internets-proxy-compromised), mostly in the form of javascript.

The obvious solution to these issues is to use TLS i.e. `https://` sites, which is more accessible these thanks to [Lets Encrypt](https://letsencrypt.org/). But even this does not give complete end-to-end coverage because many sites use a CDN who might unknowingly or maliciously tamper with the contents. 

One way to make such tampering detectable is to sign textual web-content using PGP. As a PoC, I have signed all html pages of this blog with a pgp signature. Go ahead, view source of this page, I'll wait...

Bash script (`signhtml.sh`) to perform the signing :-
```
#!/bin/sh

tmpfile=$(mktemp)
echo "using $tmpfile for $1"
echo "https://keybase.io/sajal -->" > $tmpfile #Optional text in commented area
cat $1 >> $tmpfile
echo "
<!--" >> $tmpfile
gpg --default-key BF15828F  --clearsign $tmpfile #Because im signing with non-default key
echo "<!--" > $1
cat "$tmpfile.asc" >> $1
echo "-->" >> $1
rm $tmpfile
rm "$tmpfile.asc"

```
Usage : `./signhtml.sh /path/to/file.html` . Obviously remove or adjust the `--default-key BF15828F` portion. This overwrites the existing html file without taking a backup... YOLO.

Verify the contents using:-
```
$ gpg --recv-keys BF15828F
gpg: requesting key BF15828F from hkp server keys.gnupg.net
gpg: key BF15828F: public key "Sajal Kayan <sajal83@gmail.com>" imported
gpg: no ultimately trusted keys found
gpg: Total number processed: 1
gpg:               imported: 1  (RSA: 1)
$ curl http://www.sajalkayan.com/ | gpg --verify
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 29916  100 29916    0     0  1577k      0 --:--:-- --:--:-- --:--:-- 1623k
gpg: Signature made Fri 05 Feb 2016 02:44:27 PM UTC using RSA key ID BF15828F
gpg: Good signature from "Sajal Kayan <sajal83@gmail.com>"
gpg:                 aka "<sajal@turbobytes.com>"
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: A668 BBFE 438C BEDA 7BB6  3925 3964 90AC BF15 828F
$ 
```

Now if your ISP is messing with the html body, the signature will not match. There is one caveat, if the injected contents is before or after the signed portion.

Lets take this html payload

{{% highlight html %}}
```
<html>
<head>
	<title>Hello World</title>
</head>
<body>
Hello World
</body>
</html>
```
{{% /highlight %}}

After signing it becomes :-
{{% highlight html %}}
```
<!--
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

https://keybase.io/sajal -->
<html>
<head>
	<title>Hello World</title>
</head>
<body>
Hello World
</body>
</html>

<!--
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v2.0.22 (GNU/Linux)

iQIcBAEBAgAGBQJWtgNUAAoJEDlkkKy/FYKPZpIQAI8QEsLbAMbN7uB/TNpyti0v
k/aqWKs6nvrVL0fI7nz2O1rUQFB0dYh+9wyrYhCW3BbfYv7tjwTEMwNcZT/VJEYw
EEqrKenX7S2xCpzBgiMZrMpoM6N+wmpMhi0vVnQpZIQMknhgOMvM1qjKD5gtdfeN
WjUuBfqFerjt+bFihowlfpX0f1Z70b4jO/2opL2u7YD0zMcIbkcxCTs9kVTl+q+y
RBnBJcSs10lB6wadKzdr1TKxDhxvTS0YHq5oxFnQhjLZdlQx7AJEGgAp9DTuLb5T
r5nlFtEGFLlstWyKzfr7gBmrg9fKKz0cpYRpLxCKngpv+pNqHVekO+Kw25hx9R1e
KnOvplBZNc1GdbKipi7Or1t5/sb3C13hsiDSTwvsnaA7LMhONQKyA9oG7pjabK2u
8l1ybin9Ni2+PoOfJOLikCGSxqYmqfT4Qjsy3tWQumC7tYZgsBOtig0Izu3JLqBE
DSMIZdr+hpUg8LD5pQmCLtsL70YTlE+xikH64lKKZfaYn3TwdOTrljXeGfisp4XF
4LEy1IuGui/vlfJ4Bxfh1iAdyFPzF+L8piJWu2Eme2N5FV+cKDwaPSAkGzLkDkD+
JpT5mLj6nnFI+haRNpPs0mas+eq0zi1y2gBBt5GUCmtz2FWKVjqHJU/p3rW77Opc
0UlBBV+vXL1YQjhGiZb9
=res0
-----END PGP SIGNATURE-----
-->
```
{{% /highlight %}}

Anything injected before the first `<!--` and the last `-->` will not be validated, but that portion easy to visually inspect, or write some code to check if something has been added or not.

Example of malicious stuff included which passes gpg verification.
{{% highlight html %}}
```
<script>
alert("all your head is belong to us");
</script>
<!--
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

https://keybase.io/sajal -->
<html>
<head>
	<title>Hello World</title>
</head>
<body>
Hello World
</body>
</html>

<!--
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v2.0.22 (GNU/Linux)

iQIcBAEBAgAGBQJWtgNUAAoJEDlkkKy/FYKPZpIQAI8QEsLbAMbN7uB/TNpyti0v
k/aqWKs6nvrVL0fI7nz2O1rUQFB0dYh+9wyrYhCW3BbfYv7tjwTEMwNcZT/VJEYw
EEqrKenX7S2xCpzBgiMZrMpoM6N+wmpMhi0vVnQpZIQMknhgOMvM1qjKD5gtdfeN
WjUuBfqFerjt+bFihowlfpX0f1Z70b4jO/2opL2u7YD0zMcIbkcxCTs9kVTl+q+y
RBnBJcSs10lB6wadKzdr1TKxDhxvTS0YHq5oxFnQhjLZdlQx7AJEGgAp9DTuLb5T
r5nlFtEGFLlstWyKzfr7gBmrg9fKKz0cpYRpLxCKngpv+pNqHVekO+Kw25hx9R1e
KnOvplBZNc1GdbKipi7Or1t5/sb3C13hsiDSTwvsnaA7LMhONQKyA9oG7pjabK2u
8l1ybin9Ni2+PoOfJOLikCGSxqYmqfT4Qjsy3tWQumC7tYZgsBOtig0Izu3JLqBE
DSMIZdr+hpUg8LD5pQmCLtsL70YTlE+xikH64lKKZfaYn3TwdOTrljXeGfisp4XF
4LEy1IuGui/vlfJ4Bxfh1iAdyFPzF+L8piJWu2Eme2N5FV+cKDwaPSAkGzLkDkD+
JpT5mLj6nnFI+haRNpPs0mas+eq0zi1y2gBBt5GUCmtz2FWKVjqHJU/p3rW77Opc
0UlBBV+vXL1YQjhGiZb9
=res0
-----END PGP SIGNATURE-----
-->
<script>
alert("all your base is belong to us");
</script>
```
{{% /highlight %}}

Here is a complete verification script that includes test for tampering portions not covered by PGP. -- `verifyhtml.sh`. Warning `awk` black magic ahead -- copy/pasted from the interwebs.

```
#!/bin/sh

tmpfile=$(mktemp)
#Download the file
curl -o $tmpfile $1
# checking if -----END PGP SIGNATURE----- armor is present
# Need to check for this cause gpg still validates without it.
result=`awk 'BEGIN{ found=0} /-----END PGP SIGNATURE-----/{found=1}  {if (found) print }' $tmpfile | wc -c`
if [ "$result" -eq "0" ]; then
	echo "ABORTING: -----END PGP SIGNATURE----- has been removed!!!"
	exit 1
else
	echo "-----END PGP SIGNATURE----- check passed"
fi

#Check if end has been tampered
result=`awk 'BEGIN{ found=0} /-----END PGP SIGNATURE-----/{found=1}  {if (found) print }' $tmpfile | sed -e 's/-----END PGP SIGNATURE-----//g' | sed -e 's/-->//g' | tr -d "[:space:]" | wc -c`
if [ "$result" -eq "0" ]; then
	echo "End not tampered"
else
	echo "ABORTING: Tampered at the end!!!"
	exit 1
fi
#Check if beginning has been tampered with.
result=`sed -n '1,/BEGIN PGP SIGNED MESSAGE/p' $tmpfile | sed -e 's/-----BEGIN PGP SIGNED MESSAGE-----//g' | sed -e 's/<!--//g' | tr -d "[:space:]" | wc -c`
if [ "$result" -eq "0" ]; then
	echo "Begining not tampered"
else
	echo "ABORTING: Tampered at the beginning!!!"
	exit 1
fi
echo "checking signature"
gpg --verify $tmpfile
rm $tmpfile #Perhaps keep it for debugging purpose if gpg fails to verify.
```
Usage: `./verifyhtml.sh http://www.sajalkayan.com/` . Warning: I haven't tested this enough.

This is not rock solid, i.e. the interceptor could edit the payload and sign it using another key, which could pass validations...

Similar signing techniques could be used easily for `.js` and `.css` files. In my opinion popular third party embedded javascript files should be signed using PGP and users should verify and report if any discrepancy is found.

PS: I am aware of the irony that I am talking about integrity of web payloads while not serving this blog over `https`. It is currently hosted using [github pages](https://pages.github.com/) which [does not support HTTPS for custom domains](https://github.com/isaacs/github/issues/156). I will perhaps move it elsewhere to play with Let's Encrypt and http/2.