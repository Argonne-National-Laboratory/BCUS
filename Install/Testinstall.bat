@ECHO *** BCUS Installation Test ***
@ECHO This batch file will test your installation of Ruby, R, and BCUS:

REM ruby -S UA.rb  test.osm test.epw --numLHS 3  --seed 1
@echo.

REM ruby -S SA.rb test.osm test.epw --morrisR 2 --morrisL 5  --seed 1

@echo.
ruby -S BC_Setup.rb test.osm test.epw --numLHS 6  --seed 1

@echo.

REM ruby -S BC.rb test.osm test.epw --numMCMC 30 --numBurnin 3 