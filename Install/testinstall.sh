#!/bin/bash
echo "*** BCUS Installation Test ***"
echo "This batch file will test your installation of Ruby, R, and BCUS:"
echo ""
echo "ruby -S run_analysis.rb test.osm test.epw --runType UA --numLHD 3 --seed 1"
ruby -S run_analysis.rb test.osm test.epw --runType UA --numLHD 3 --seed 1
echo ""
echo "ruby -S run_analysis.rb test.osm test.epw --runType SA --morrisR 2 --morrisL 5 --seed 1"
ruby -S run_analysis.rb test.osm test.epw --runType SA --morrisR 2 --morrisL 5 --seed 1
echo ""
echo "ruby -S run_analysis.rb test.osm test.epw --runType PreRuns --numLHD 6  --seed 1"
ruby -S run_analysis.rb test.osm test.epw --runType PreRuns --numLHD 6  --seed 1
echo ""
echo "ruby -S BC.rb test.osm test.epw --numMCMC 30 --numBurnin 3"
ruby -S BC.rb test.osm test.epw --numMCMC 30 --numBurnin 3 