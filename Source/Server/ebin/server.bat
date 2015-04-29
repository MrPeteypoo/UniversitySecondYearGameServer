@echo off

set port=20200
set /p port=Enter a port number (default - %port%)?:

erl -name server@127.0.0.1 -setcookie peteypoo -noshell -eval "flaky_snakey_server:start(normal,%port%)" -eval "init:stop()"