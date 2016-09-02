@ECHO *** BCUS Installation Test ***

@echo.
ruby -S BC_Setup.rb test.osm test.epw --numLHS 6  --seed 1

@echo.

ruby -S BC.rb test.osm test.epw --numMCMC 30 --numBurnin 3 