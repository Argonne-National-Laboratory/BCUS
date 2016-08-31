ECHO "Uncertainty Analysis"
ECHO "This bash file will run the uncertainty analysis in following commands:"
ECHO "ruby -S UA.rb  --osmName --epwName --interactive --noCleanup --uqRepo --outfile --numLHS --seed --v"

export BCUS="C:\Yuna\github\BCUS"
export RUBYPATH="$BCUS\Example"
ruby -S UA.rb  ExampleBuilding.osm Weather_USA_PA_Willow.Grove.NAS.724086_TMY3.epw --numLHS 5  --seed 1











