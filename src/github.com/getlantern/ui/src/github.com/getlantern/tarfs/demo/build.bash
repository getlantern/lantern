#!/bin/bash

mkdir resourcestar
cd resources
tar -cf ../resourcestar/resources.tar .
cd ../
go-bindata -nomemcopy -nocompress -pkg main -prefix resourcestar -o resources.go resourcestar