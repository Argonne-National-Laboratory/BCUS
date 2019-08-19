@echo off
echo Bayesian Calibration
echo This bash file will run the Bayesian calibration in following commands:
echo ruby -S BC.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --priorsFile Prior.csv --utilityData Utility.csv --numLHD 10 --numMCMC 200 --numBurnin 3 --seed 1 --numProcesses 3 --noRunCal --verbose

ruby -S BC.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --priorsFile Prior.csv --utilityData Utility.csv --numLHD 10 --numMCMC 200 --numBurnin 3 --seed 1 --numProcesses 3 --noRunCal --verbose
