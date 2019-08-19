@echo off
echo Uncertainty Analysis
echo This bash file will run the uncertainty analysis in following commands:
echo ruby -S UA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --uqRepo Example_Repository.xlsx --numLHD 6 --seed 1 --numProcesses 3 --verbose

ruby -S UA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --uqRepo Example_Repository.xlsx --numLHD 6 --seed 1 --numProcesses 3 --verbose
