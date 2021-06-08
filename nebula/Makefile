111MODULE = on
export GO111MODULE

mobileNebula.aar: *.go go.sum
	gomobile bind -trimpath -v --target=android

MobileNebula.framework: *.go go.sum
	gomobile bind -trimpath -v --target=ios

.DEFAULT_GOAL := mobileNebula.aar

all: mobileNebula.aar MobileNebula.framework
