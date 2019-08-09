ECHO "Bayesian Calibration"
ECHO "This bash file will run the Bayesian calibration in following commands:"
ECHO "ruby -S BC.rb  --osmName --epwName --priorsFile --utilityData --outfile --simFile --fieldFile --postsFile --pvalsFile --numLHD --numMCMC --numOutVars --numWVars --numBurnin --seed --numProcesses --noSim --noEP --noCleanup --noPlots --noRunCal --interactive --verbose"

ruby -S BC.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --priorsFile Prior.csv --utilityData Utility.csv --numLHD 10 --numMCMC 200 --numBurnin 3 --seed 1 --numProcesses 3 --noRunCal --verbose
