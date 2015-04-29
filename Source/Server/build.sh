#!/bin/bash

mkdir ebin
mkdir ../../Builds
mkdir ../../Builds/Server/

erl -make
cp -r ebin/. ../../Builds/Server/
