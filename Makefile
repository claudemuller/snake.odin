BIN := snake

run:
	odin run . -out=${BIN}

release-dir:
	rm -rf ./release
	mkdir -p release

clean:
	rm -rf ./build/*

release-linux: release-dir clean
	odin build . -out=build/${BIN}-lin
	cp -r ./res ./build/
	zip -r ./release/linux.zip ./build

release-darwin: release-dir clean
	odin build . -out=build/${BIN}-mac
	cp -r ./res ./build/
	zip -r ./release/macos.zip ./build
