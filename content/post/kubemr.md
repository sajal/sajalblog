+++
date = "2017-04-20T20:00:00+00:00"
draft = false
title = "kubemr: Kubernetes native distributed MapReduce framework"
tag = ["kubernetes", "mapreduce", "go", "golang"]
+++

tl;dr version [https://github.com/turbobytes/kubemr](https://github.com/turbobytes/kubemr)

### Background

Few years ago I wrote a [MapReduce](https://en.wikipedia.org/wiki/MapReduce) tool in Go called [gomr](https://github.com/turbobytes/gomr). I never used it for anything, just wrote it as an experiment to see if I could run MapReduce jobs without requiring a master, and it worked. The distributed consensus is provided by etcd which is typically deployed as a cluster. I am not fond of master/slave or primary/secondary systems. I like it when individual units are responsible and co-ordinate with each other and do their fair share of work.

gomr used S3 to upload user binaries and store map/reduce outputs and results. A running worker would query etcd for pending jobs, fetch binary from S3 and then `Exec()` it.

This week I re-wrote the tool to let [Kubernetes](https://kubernetes.io/) take care of a lot of the deployment hassles and called it [*kubemr*](https://github.com/turbobytes/kubemr). Yes, I am aware I suck at naming things.

### Introducing kubemr

kubemr is a MapReduce system that runs within a Kubernetes cluster. Apart from initial complexity of setting up the cluster and managing it, kubemr itself is pretty simple.

#### Getting started

https://github.com/turbobytes/kubemr/blob/master/README.md

#### JSON Patch

Originally I planned to use etcd for state, but instead, I decided to use [JSON patch](http://jsonpatch.com/) functionality [provided by kubernetes](https://github.com/kubernetes/community/blob/master/contributors/devel/api-conventions.md#patch-operations) to make changes to this state. The `test` operation allows the patch to fail if some condition is not met.

Example lock using JSON patch :-

```
[
  { "op": "test", "path": "/lockholder", "value": None },
  { "op": "add", "path": "/lockholder", "value": "me" },
]
```

Above operation would fail if the `lockholder` already has a value. So multiple users might try to acquire the lock at the same time but only 1 would succeed.

#### Job state

All state information about a MapReduce task is stored in a kubernetes ThirdPartyResource.

In the case of kubemr, I named it `MapReduceJob`. All I need to kick off some task is submit the following example yaml to Kubernetes.

{{< highlight yaml >}}
apiVersion: "turbobytes.com/v1alpha1"
kind: MapReduceJob
metadata:
  generateName: test-
spec:
  image: turbobytes/kubemr-wordcount
  replicas: 10
  inputs:
  - https://tools.ietf.org/rfc/rfc4501.txt
  - https://tools.ietf.org/rfc/rfc2017.txt
  - https://tools.ietf.org/rfc/rfc2425.txt
{{< /highlight >}}

The image `turbobytes/kubemr-wordcount` knows how to process this. I used `generateName` instead of the usual `name` to ask Kubernets to generate a random unique suffix.

Once the job is complete, something like this is stamped onto the object.

{{< highlight yaml >}}
results:
- s3://kubemr/kubemr/test-z0dk5/reduce/0.txt
- s3://kubemr/kubemr/test-z0dk5/reduce/1.txt
- s3://kubemr/kubemr/test-z0dk5/reduce/2.txt
- s3://kubemr/kubemr/test-z0dk5/reduce/3.txt
- s3://kubemr/kubemr/test-z0dk5/reduce/4.txt
{{< /highlight >}}

#### Lifecycle of a MapReduceJob

1. User creates a [MapReduceJob object](https://github.com/turbobytes/kubemr/blob/master/manifests/wordcount.yaml)
2. The [operator](https://github.com/turbobytes/kubemr/blob/master/manifests/operator-deployment.yaml) sees there is no `status` field, it validates the schema and either marks it as `FAIL` if invalid or `PENDING`.
3. An operator marks status as `DEPLOYING` if status is `PENDING`. This guarantees a lock to a single operator instance (in case multiple are running).
4. The operator creates desired `ConfigMap` and `Secret` objects needed for the `Job`.
5. The operator [creates the Kubernetes Job object](https://github.com/turbobytes/kubemr/blob/4a19b75819f57bcecf0dfcb0d69eda1070f7dbbc/pkg/job/client.go#L164) and marks status as `DEPLOYED`. It creates n worker pods where n is determined by `replicas` field in the manifest in step #1. In this example it is 10.
6. As workers come online, they pick a map task, on successfully acquiring a lock they execute it and populate the `outputs` field. Each output belongs to a particular *partition*
7. Once all map tasks are complete, a worker creates reduce stage specification in the `MapReduceJob`. Only a single worker would succeed in doing so because we use [JSON patch](https://github.com/kubernetes/community/blob/master/contributors/devel/api-conventions.md#patch-operations). A single reduce task corresponds to a partition created during map phase with all outputs belonging to that partition used as input for the reduce.
8. The workers start executing reduce stage.
9. When all reduce tasks are completed successfully, a worker aggregates all reduce outputs into a list saves it as `results` and marks the `MapReduceJob` as `COMPLETE`.

If any thing fails along the way, the entire `MapReduceJob` is marked as `FAIL`. *Do or do not, there is no try.*

The inputs and outputs here are just strings. We do provide utility methods to fetch/store files as S3 objects, but the meaning of the string is up to the user.

#### Components

##### Operator

https://github.com/turbobytes/kubemr/tree/master/cmd/operator

The operator watches for `MapReduceJob`s and creates Kubernetes resources for it

##### Worker

Example: https://github.com/turbobytes/kubemr/tree/master/cmd/wordcount

This is user supplied docker image. It must have `CMD` or `ENTRYPOINT` defined. The actual code needs to basically satisfy [JobWorker interface](https://godoc.org/github.com/turbobytes/kubemr/pkg/worker#JobWorker).

The user could actually write the worker in any language, as long as they implement everything that the Go library does. Perhaps in future I could provide wrappers to allow workers to be written as shell commands.

##### API server

TODO: Not yet implemented.

Will probably have some way to stream results, and some way to retry failed jobs, etc.

#### Differences from gomr

1. Worker code is shipped as user generated docker images
2. Kubernetes apiserver(which itself is backed by etcd) is used for consensus. This means I don't have to make maintain tooling to create job objects.
3. When a new job comes in, we create kubernetes [batch jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/) to run the user-provided docker images.

#### Disclaimer

1. This is pre-pre-pre-alpha. Use at your own risk. There may be backwards-incompatible changes.
2. I am not cleaning up after myself properly. If playing with it in a production cluster, do everything in a new namespace and simply delete the namespace once done.
3. I have not retrying any failed tasks. Probably not fine to put a 10GB job only to find out some intermittent DNS timeout broke the job.
4. I don't know what guarantees the kube-apiserver provides about the JSON Patch. Especially in multi-master environments.

### Conclusion

I had fun building this. Hope you have fun playing with it too.

Looking forward to using this at [work](http://www.turbobytes.com/) in the near future.

Special thanks to [Aaron Schlesinger](http://arschles.com/). His [talk](https://www.youtube.com/watch?v=qiB4RxCDC8o) and the corresponding [example code](https://github.com/arschles/2017-KubeCon-EU) helped a lot.
