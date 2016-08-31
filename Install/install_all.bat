@echo off
REM Set up the BCUS paths for the ruby scripts and batch files
call setpaths.bat

REM install the R packages from within R using rinruby
call install_R_packages.bat

REM install the ruby gems
call install_ruby_gems.bat

echo DONE!  Installation is complete.
echo Run the install test batch file to test installation


