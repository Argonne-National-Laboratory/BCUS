ECHO "Sensitivity Analysis"
ECHO "This bash file will run the sensitivity analysis in following commands:"
ECHO "ruby -S SA.rb --osmName --epwName --interactive --noCleanup --uqRepo --outfile --morrisR --morrisL --seed --v"

export BCUS="C:\Yuna\github\BCUS"
export RUBYPATH="$BCUS\Example"
ruby -S SA.rb ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --morrisR 5  --morrisL 50 --seed 1 --v   
