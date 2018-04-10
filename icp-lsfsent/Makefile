#--------------------------------------------------------
# Copyright IBM Corp. 1992, 2017. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#--------------------------------------------------------

# The version set below will override the Chart.yaml versions
VER=10.2
ARCH=$(shell arch)
IMAGENAME=lsfsent

# Set this to the value of YOUR repo server
REPO=http://10.10.10.1/helm-repo

default: image

image: Dockerfile.${ARCH}
	cp Dockerfile.${ARCH} Dockerfile
	docker build --rm --cpuset-cpus="0-1" -t ${IMAGENAME}:${VER}-${ARCH} .

setver:
	@find helm/. -type f -name "Chart.yaml" -exec sed -i -e "s/^version\:.*/version\: ${VER}/g" {} \;
	@find helm/. -type f -name "values.yaml" -exec sed -i -e "s|\(.*\)tag: 10.*|\1tag: ${VER}-${ARCH}|g" {} \;


cleanall:
	-@rm -rf helm/index.yaml helm/*.tgz

repofiles:
	cd helm ; \
	helm package icp-lsfsent ; \
	helm repo index --url ${REPO} --debug .

