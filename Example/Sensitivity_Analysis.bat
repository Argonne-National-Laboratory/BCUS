@echo off
echo Sensitivity Analysis
echo This bash file will run the sensitivity analysis in following commands:
echo ruby -S SA.rb --osm --epw --uqRepo --outFile --morrisR --morrisL --seed --numProcesses --noEP --noCleanup --interactive --verbose

ruby -S SA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --morrisR 5 --morrisL 50 --seed 1 --numProcesses 3 --verbose
