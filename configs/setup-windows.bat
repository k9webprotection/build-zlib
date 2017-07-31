@echo off
IF NOT EXIST "%MSBUILD_EXE%" (
    echo MSBuild does not exist at "%MSBUILD_EXE%"> 1&2
    echo. 1>2
    exit /B 1
)
exit /B 0
