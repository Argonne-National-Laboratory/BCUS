@ECHO *** BCUS Installation Test ***
@ECHO This batch file will test your installation of Ruby, R, and SA in BCUS:

ruby -S SA.rb test.osm test.epw --morrisR 2 --morrisL 4  --seed 1 %1 %2 %3 %4

