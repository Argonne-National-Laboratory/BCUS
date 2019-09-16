@echo off
REM Install the required R packages using rinruby so they are in an accessible place
mkdir ..\Rlib
echo Installing R packages "sensitivity", "ggplot2", "triangle", "gridextra", "lhs", "car'
ruby -S Install_Rpackages.rb
