#!/bin/sh

#usage: ./deploy.sh /path/to/private/key.pem
set -e
rm -rfv public/*
hugo --theme=hyde --uglyUrls=true
cp -r public/* ../sajal.github.io/
cp ../sajal.github.io/post.xml ../sajal.github.io/feed.xml
echo "Signing"
find ../sajal.github.io/ | grep '\.html' | xargs -n1 -iX  ./signhtml.sh 'X'
echo "Update done"
