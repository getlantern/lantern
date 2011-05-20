set base_dir=%~p0

set tests=%1
if "%tests%" == "" set tests="all"

java -jar "%base_dir%/../test/lib/jstestdriver/JsTestDriver.jar" ^
	 --config "%base_dir%/../config/jsTestDriver.conf" ^
	 --basePath "%base_dir%/.." ^
	 --tests "%tests%"

