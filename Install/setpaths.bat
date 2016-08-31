@echo off

REM Set up the BCUS paths for the ruby scripts and batch files
echo Current Directory is %CD%
pushd ..
echo Setting BCUSDIR=%CD%
set BCUSDIR=%CD%
setx BCUSDIR "%CD%"
echo BCUSDIR=%BCUSDIR%
echo.

echo setting BCUSCODE=%BCUSDIR%\BCUSCode
set BCUSCODE=%BCUSDIR%\BCUSCode
setx BCUSCODE "%BCUSDIR%\BCUSCode"
echo.

echo Setting RUBYPATH=%BCUSCODE%
setx RUBYPATH "%BCUSCODE%"
set RUBYPATH=%BCUSCODE%
popd