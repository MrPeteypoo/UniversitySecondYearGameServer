@echo off

if not exist ..\..\Builds mkdir ..\..\Builds
if not exist ..\..\Builds\Server mkdir ..\..\Builds\Server

erl -make
XCOPY /S /Y ebin ..\..\Builds\Server