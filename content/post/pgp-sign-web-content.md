+++
date = "2016-02-06T18:18:00+00:00"
draft = false
title = "Sign web content using PGP"
tag = ["html", "pgp"]
+++

A lot of web-content these days passes thru untrusted intermediaries, especially plain text traffic which is often [intercepted by ISP proxies](http://www.sajalkayan.com/4-reasons-why-i-love-my-isp.html) for caching (and other purposes ;) ). A compromise at these places [can subject your users to malicious payload](http://www.telecomasia.net/content/true-internets-proxy-compromised), mostly in the form of javascript.

The obvious solution to these issues is to use TLS i.e. `https://` sites, which is more accessible these days thanks to [Lets Encrypt](https://letsencrypt.org/). But even this does not give complete end-to-end coverage because many sites use a CDN who might unknowingly or maliciously tamper with the contents. 

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
gpg --digest-algo SHA256 --default-key BF15828F  --clearsign $tmpfile #Because im signing with non-default key
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
```
<!--
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

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

iQIcBAEBCAAGBQJWtil3AAoJEDlkkKy/FYKPuawQAIAZ72rb/B+W1d1XGkXfxE0m
eUr3lE39FCLGJbroQyWzJFl3384EpDo9nSToN8y0ln6h1nohgykAma9YFAHMrRb1
0+f8FvUzAMnyaT1xSVmke6zgA2/X0sPIhMDHTUDCgvSFOtk21RgVySpTJ584013u
foroZxzloZz6vFAFh/OQhtoyaA8Br3dk0YleO5N/ApPsZZjC9hSiyfHh/kJr+71y
d6Y+EWyR+XQDpjQtyZtQIu34zJYUCTn+0iWPTLmB3pn1jgWg7dfxqJq5XNHRE2Sj
79vRQmQhzps3IYaWU+Ogauf59mVcgGV3GytL/xt5o9PsVi6g+Yo4l2xF8oC2EKwM
JYqdsvWtFAk7guxf8v9kP5aUcuA0TnW/H9VVH6oWqHgQKqWYkOcMMrZDGr3aLRiV
8mDQPP/iZgTlhI0s5Yrn7jBubHbM19qdqADHp+7Jr72qzQzDa0Qiblk4nGyEiYIg
xGGbRfHfKThVajhx6y3ggdEP6DTHTcCNLItS7OQY3pocXszCGYd1IuLRPFjKoaGh
td18ycpL2Dhq/HyOjIDcvyzliyU8YcqHFBQaWIhBw03hNFlgjUOedI/glU9IT6hY
nPdDtji6rkfL55KbZrCbYQL6Ai4LQxLOJTCrzr8tu8tEfzK1lry9ztDgmn4R9XDv
pssWJDftlfXtU4ncmdF2
=MhMl
-----END PGP SIGNATURE-----
-->
```

Anything injected before the first `<!--` and the last `-->` will not be validated, but that portion easy to visually inspect, or write some code to check if something has been added or not.

Example of malicious stuff included which passes gpg verification.
```
<script>
alert("all your head is belong to us");
</script>
<!--
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

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

iQIcBAEBCAAGBQJWtil3AAoJEDlkkKy/FYKPuawQAIAZ72rb/B+W1d1XGkXfxE0m
eUr3lE39FCLGJbroQyWzJFl3384EpDo9nSToN8y0ln6h1nohgykAma9YFAHMrRb1
0+f8FvUzAMnyaT1xSVmke6zgA2/X0sPIhMDHTUDCgvSFOtk21RgVySpTJ584013u
foroZxzloZz6vFAFh/OQhtoyaA8Br3dk0YleO5N/ApPsZZjC9hSiyfHh/kJr+71y
d6Y+EWyR+XQDpjQtyZtQIu34zJYUCTn+0iWPTLmB3pn1jgWg7dfxqJq5XNHRE2Sj
79vRQmQhzps3IYaWU+Ogauf59mVcgGV3GytL/xt5o9PsVi6g+Yo4l2xF8oC2EKwM
JYqdsvWtFAk7guxf8v9kP5aUcuA0TnW/H9VVH6oWqHgQKqWYkOcMMrZDGr3aLRiV
8mDQPP/iZgTlhI0s5Yrn7jBubHbM19qdqADHp+7Jr72qzQzDa0Qiblk4nGyEiYIg
xGGbRfHfKThVajhx6y3ggdEP6DTHTcCNLItS7OQY3pocXszCGYd1IuLRPFjKoaGh
td18ycpL2Dhq/HyOjIDcvyzliyU8YcqHFBQaWIhBw03hNFlgjUOedI/glU9IT6hY
nPdDtji6rkfL55KbZrCbYQL6Ai4LQxLOJTCrzr8tu8tEfzK1lry9ztDgmn4R9XDv
pssWJDftlfXtU4ncmdF2
=MhMl
-----END PGP SIGNATURE-----
-->
<script>
alert("all your base is belong to us");
</script>
```

Here is a complete verification script that includes test for tampering portions not covered by PGP. -- `verifyhtml.sh`. Warning `awk` black magic ahead -- copy/pasted snippets from the interwebs.

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
Usage: `./verifyhtml.sh http://www.sajalkayan.com/` . 

*Warning: I haven't tested this enough. This is not rock solid, i.e. the interceptor could edit the payload and sign it using another key, which could pass validations...*

Similar signing techniques could be used easily for `.js` and `.css` files. In my opinion popular third party embedded javascript files should be signed using PGP and users should verify and report if any discrepancy is found.

PS: I am aware of the irony that I am talking about integrity of web payloads while not serving this blog over `https`. It is currently hosted using [github pages](https://pages.github.com/) which [does not support HTTPS for custom domains](https://github.com/isaacs/github/issues/156). I will perhaps move it elsewhere to play with Let's Encrypt and http/2.