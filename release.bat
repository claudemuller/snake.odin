del build
mkdir build
mkdir build\res
copy res build\res
odin build . -out=build\snake.exe
del release
mkdir release
powershell Compress-Archive build\* release\windows.zip
