BIN := snake

run:
	odin run . -out=${BIN}

release-linux:
	odin build . -out=build/${BIN}-lin

release-darwin:
	odin build . -out=build/${BIN}-mac
