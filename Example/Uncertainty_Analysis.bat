ECHO "Uncertainty Analysis"
ECHO "This bash file will run the uncertainty analysis in following commands:"
ECHO "ruby -S UA.rb  --osmName --epwName --uqRepo --numLHD --outFile --seed --numProcesses --noEP --noCleanup --verbose"

ruby -S UA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --uqRepo Example_Repository.xlsx --numLHD 6 --seed 1 --numProcesses 3 --verbose
