#!/bin/bash

erl -name shutdown@127.0.0.1 -setcookie peteypoo -noshell -eval "net_kernel:connect_node('server@127.0.0.1')" -eval "register(flaky_snakey_server,self())" -eval "{snake_server,'server@127.0.0.1'} ! shutdown" -eval "init:stop()"