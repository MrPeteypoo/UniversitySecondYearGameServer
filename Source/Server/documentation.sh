#!/bin/bash

mkdir ../../Docs
mkdir ../../Docs/Server

output="'../../../Docs/Server'"

cd ebin
erl -noshell -eval "edoc:application(flaky_snakey_server, '..', [{private, true}, {dir,$output}])" -eval "init:stop()"
cd ..
