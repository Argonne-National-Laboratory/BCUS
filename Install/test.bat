@echo off
echo *** BCUS Installation Test ***
echo This batch file will test your installation of Ruby, R, and BCUS:

echo ruby -S UA.rb test.osm test.epw --numLHD 3 --seed 1 --numProcesses 3
ruby -S UA.rb test.osm test.epw --numLHD 3 --seed 1 --numProcesses 3
echo.

echo ruby -S SA.rb test.osm test.epw --morrisR 2 --morrisL 5 --seed 1 --numProcesses 3
ruby -S SA.rb test.osm test.epw --morrisR 2 --morrisL 5 --seed 1 --numProcesses 3
echo.

echo ruby -S BC.rb test.osm test.epw --numLHD 6 --numMCMC 30 --numBurnin 3 --seed 1 --numProcesses 3
ruby -S BC.rb test.osm test.epw --numLHD 6 --numMCMC 30 --numBurnin 3 --seed 1 --numProcesses 3
echo.

echo ruby -S BC.rb test.osm test.epw --numLHD 6 --numMCMC 30 --numBurnin 3 --seed 1 --noSim
ruby -S BC.rb test.osm test.epw --numLHD 6 --numMCMC 30 --numBurnin 3 --seed 1 --noSim
