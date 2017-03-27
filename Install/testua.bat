@ECHO *** BCUS Installation Test ***
@ECHO This batch file will test your installation of Ruby, R, and BCUS:

ruby -S UA.rb  test.osm test.epw --numLHS 2  --seed 1
@echo.
