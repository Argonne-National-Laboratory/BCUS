@ECHO "Bayesian Calibration"
@ECHO "This bash file will run the Bayesian Calibration Setup and Bayesian Calibration in following commands:"
@ECHO "ruby -S BC_Setup.rb  --osmName --epwName --outfile --priorsFile --utilityData --numLHS --seed 1  --noCleanup --verbose"
@ECHO "ruby -S BC.rb  --osmName --epwName --comFile --fieldFile --numMCMC --numOutVars --numWVars --numBurnin --priorsFile --postsFile --seed --noRunCal --noCleanup --verbose"

ruby -S BC_Setup.rb --osmName ExampleBuilding.osm --epwName Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --numLHS 10 --priors Prior.csv --utilityData Utility.csv
ruby -S BC.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --numMCMC 200 --numBurnin 3  --noRunCal --priorsFile Prior.csv 
