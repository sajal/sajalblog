#!/bin/sh

tmpfile=$(mktemp)
echo "using $tmpfile for $1"
echo "https://keybase.io/sajal -->" > $tmpfile
cat $1 >> $tmpfile
echo "
<!--" >> $tmpfile

gpg --digest-algo SHA256 --default-key BF15828F  --clearsign $tmpfile

echo "<!--" > $1

cat "$tmpfile.asc" >> $1

echo "-->" >> $1

rm $tmpfile
rm "$tmpfile.asc"
