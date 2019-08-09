ECHO "Sensitivity Analysis"
ECHO "This bash file will run the sensitivity analysis in following commands:"
ECHO "ruby -S SA.rb --osmName --epwName --uqRepo --morrisR --morrisL --outFile --seed --numProcesses --noEP --noCleanup --interactive --verbose"

ruby -S SA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --uqRepo Example_Repository.xlsx --morrisR 5 --morrisL 50 --seed 1 --numProcesses 3 --verbose   
