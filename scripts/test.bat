@echo off

REM Windows script for running unit tests
REM You have to run server and capture some browser first
REM
REM Requirements:
REM - Java (http://www.java.com)

set BASE_DIR=%~dp0

java -jar "%BASE_DIR%\..\test\lib\jstestdriver\JsTestDriver.jar" ^
     --config "%BASE_DIR%\..\config\jsTestDriver.conf" ^
     --basePath "%BASE_DIR%\.." ^
     --tests all
