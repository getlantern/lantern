@echo off

REM Windows script for running e2e tests
REM You have to run server and capture some browser first
REM
REM Requirements:
REM - Java (http://www.java.com)

set BASE_DIR=%~dp0
testacular start "%BASE_DIR%\..\config\testacular-e2e.conf.js"
