@ECHO *** BCUS Installation Test ***
@ECHO This batch file will test your installation of Ruby, R, and UA in BCUS:

ruby -S UA.rb  test.osm test.epw --numLHS 4  --seed 1

