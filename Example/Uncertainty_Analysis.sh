#!/bin/bash
echo "Uncertainty Analysis"
echo "This bash file will run the uncertainty analysis in following commands:"
echo "ruby -S UA.rb --osm --epw --uqRepo --outFile --numLHD --seed --numProcesses --noEP --noCleanup --interactive --verbose"

ruby -S UA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --numLHD 6 --numProcesses 3 --seed 1 --verbose
