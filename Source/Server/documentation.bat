@echo off

if not exist ..\..\Docs mkdir ..\..\Docs
if not exist ..\..\Docs\Server mkdir ..\..\Docs\Server

set output='../../../Docs/Server'

cd ebin
erl -noshell -eval "edoc:application(flaky_snakey_server, '../', [{private, true}, {dir,%output%}])" -eval "init:stop()"
cd ..