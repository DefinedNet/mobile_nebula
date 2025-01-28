111MODULE = on
export GO111MODULE

unexport SWIFT_DEBUG_INFORMATION_VERSION
unexport SWIFT_DEBUG_INFORMATION_FORMAT

clean:
	rm -rf mobileNebula.aar MobileNebula.xcframework

mobileNebula.aar: *.go go.sum
	gomobile bind -trimpath -v -x --target=android/arm64 -androidapi=26

MobileNebula.xcframework: *.go go.sum
	gomobile bind -trimpath -v -target=ios

.DEFAULT_GOAL := mobileNebula.aar

.PHONY: clean
all: mobileNebula.aar MobileNebula.framework
