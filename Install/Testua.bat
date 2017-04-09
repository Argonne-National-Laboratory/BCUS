@ECHO *** BCUS Installation Test ***
@ECHO This batch file will test your installation of Ruby, R, and UA in BCUS:

ruby -S UA.rb  test.osm test.epw --numLHS 2  --seed 1  %1 %2 %3 %4

