+++
date = "2015-03-15T20:43:00+00:00"
draft = false
title = "http/2 is stricter than http/1.1"
tag = []
+++

I am starting to read the [draft http/2 spec](https://tools.ietf.org/html/draft-ietf-httpbis-http2-17) and realized its quite strict and leaves little to interpreter's imagination.

Here are the wordcounts for various specs for following words : *MUST*, *REQUIRED*, *SHALL*, *SHOULD*, *RECOMMENDED*, *MAY*, *OPTIONAL*

| RFC                                | Total | MUST         | SHOULD       | MAY          | SHALL | REQUIRED | RECOMMENDED | OPTIONAL |
|------------------------------------|:-----:|-------------:|-------------:|-------------:|------:|---------:| -----------:|---------:|
| rfc2616 (http/1.1)                 | 799   | 348 (43.55%) | 256 (32.04%) | 180 (22.53%) | 2     | 5        | 1           | 7        |
| rfc723\[0-5\] (superseeds rfc2616) | 668   | 344 (51.50%) | 163 (24.40%) | 126 (18.86%) | 12    | 6        | 7           | 10       |
| http2-17 (http/2)                  | 296   | 219 (73.99%) | 31 (10.47%)  | 41 (13.65%)  | 2     | 1        | 1           | 1        |

To be fair... http/2 spec does not divulge into header behavior, caching, etc. *SHALL*, *REQUIRED*, *RECOMMENDED* and *OPTIONAL* were only found in the [section](https://tools.ietf.org/html/draft-ietf-httpbis-http2-17#section-2.2) defining the keywords.

```
The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in RFC 2119 [RFC2119].
```

I did not include HTTP/1 for this comparison because the spec does not seem to use upper cased keywords.

Quick and dirty python script to do the word counts.

{{% highlight python %}}
```
import re
from httplib2 import Http
from collections import defaultdict

h = Http()

WORDS = ["MUST", "REQUIRED", "SHALL",
   "SHOULD", "RECOMMENDED", "MAY", "OPTIONAL"]

def get_counts(string, counts):
    for w in re.split('\W', string):
        if w:
            for W in WORDS:
                if W == w:
                    counts[w] += 1
    return counts


def count_url(url, counts):
    r,c = h.request(url)
    return get_counts(c, counts)

def summarize(counts):
    total = 0
    for k in counts.keys():
        total += counts[k]
    counts = dict(counts)
    counts["total"] = total
    counts["mustpct"] = counts["MUST"] * 100.0 / total
    counts["shouldpct"] = counts["SHOULD"] * 100.0 / total
    counts["maypct"] = counts["MAY"] * 100.0 / total
    return counts


if __name__ == "__main__":
    print "rfc2616" , summarize(count_url("http://tools.ietf.org/html/rfc2616", defaultdict(int)))
    counts = count_url("https://tools.ietf.org/html/rfc7230", defaultdict(int))
    counts = count_url("https://tools.ietf.org/html/rfc7231", counts)
    counts = count_url("https://tools.ietf.org/html/rfc7232", counts)
    counts = count_url("https://tools.ietf.org/html/rfc7233", counts)
    counts = count_url("https://tools.ietf.org/html/rfc7234", counts)
    counts = count_url("https://tools.ietf.org/html/rfc7235", counts)
    print "rfc723[0-5]", summarize(counts)
    print "draft-ietf-httpbis-http2-17", summarize(count_url("https://tools.ietf.org/id/draft-ietf-httpbis-http2-17.txt", defaultdict(int)))
```
{{% /highlight %}}
