#!/bin/bash

defaultport=20200

read -p "Enter a port number: " -e -i $defaultport port

erl -name server@127.0.0.1 -setcookie peteypoo -noshell -eval "flaky_snakey_server:start(normal,$port)" -eval 'init:stop()' | tee log.txt