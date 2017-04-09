@ECHO *** BCUS Installation Test ***
@ECHO This batch file will test your installation of Ruby, R, and BC in BCUS:


@echo.
ruby -S BC_Setup.rb test.osm test.epw --numLHS 6  --seed 1 %1 %2 %3 %4

@echo.

ruby -S BC.rb test.osm test.epw --numMCMC 30 --numBurnin %1 %2 %3 %4