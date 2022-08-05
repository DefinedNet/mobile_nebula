111MODULE = on
export GO111MODULE


clean:
	rm -rf mobileNebula.aar MobileNebula.xcframework

mobileNebula.aar: *.go go.sum
	go get -d golang.org/x/mobile/cmd/gomobile
	gomobile bind -trimpath -v --target=android

MobileNebula.xcframework: *.go go.sum
	go get -d golang.org/x/mobile/cmd/gomobile
	gomobile bind -trimpath -v -target=ios

.DEFAULT_GOAL := mobileNebula.aar

.PHONY: clean
all: mobileNebula.aar MobileNebula.framework
