=begin of comments
Copyright © 2016 , UChicago Argonne, LLC
All Rights Reserved
OPEN SOURCE LICENSE

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.  Software changes, modifications, or derivative works, should be noted with comments and the author and organization’s name.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

4. The software and the end-user documentation included with the redistribution, if any, must include the following acknowledgment:

   "This product includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.”

******************************************************************************************************
DISCLAIMER

THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

***************************************************************************************************


Modified Date and By:
- August 2016 by Yuna Zhang
- Created on February 15 2015 by Yuming Sun from Argonne National Laboratory


1. Introduction
This is the main code used for setting up files for running Bayesian calibration.

=end


#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for setting up files for running Bayesian calibration
#

require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
require_relative 'LHS_Gen'
require_relative 'Read_Simulation_Results_SQL'
require_relative 'rinruby'

require 'openstudio'
require 'optparse'
require 'fileutils'
require 'csv'
require 'rubyXL'


def writeToFile(results, filename, verbose = false)
	File.open(filename, "w+") do |f|
		for resultsRow in results
			for r in resultsRow
				f.write(r)
				f.write("\t")
			end
      f.write("\n")
		end
  end
	puts "Run results have been written to #{filename}" if verbose
end

# parse commandline inputs from the user
options = {:osmName=> nil, :epwName=>nil}
parser = OptionParser.new do|opts|
	opts.banner = "Usage: PreRuns_Calibration.rb [options]"

	opts.on('--osmName osmName', 'osmName') do |osmName|
		options[:osmName] = osmName
	end

	opts.on('--epwName epwName', 'epwName') do |epwName|
		options[:epwName] = epwName
	end
  
	options[:outFile] = 'Simulation_Output_Settings.xlsx'
	opts.on('-o', '--outfile outFile','Simulation Output Setting File (default=Simulation_Output_Settings.xlsx)') do |outFile|
		options[:outFile] = outFile
	end  
  
	options[:priorsFile] = 'priors.csv'
	opts.on('--priors priorsFile', 'CSV File with prior uncertainty distribution info (default=priors.csv)') do |priorsFile|
		options[:priorsFile] = priorsFile
	end

	options[:utilityData] = 'utilitydata.csv'
	opts.on('--utilityData utilityData', 'CSV File with utility data (default=utilitydata.csv)') do |utilityData|
		options[:utilityData] = utilityData
	end
  
	options[:numLHS] = 100
	opts.on('--numLHS numLHS', 'Number of LHS points (default = 100)') do |numLHS|
		options[:numLHS] = numLHS
	end
  
	options[:randseed] = 0
	opts.on('--seed seednum','Integer random number seed, 0 = no seed, default = 0') do |seednum|
		options[:randseed] = seednum
	end
  
	options[:noCleanup] = false
	opts.on('-n','--noCleanup','Do not clean up intermediate files') do 
		options[:noCleanup] = true
	end
  
	options[:verbose] = false
	opts.on('-v','--verbose','Run in verbose mode with more output info printed') do 
		options[:verbose] = true
	end
  
	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end
end

parser.parse!

# if the user didn't give the --osmName option, parse the rest of the input arguments for a *.osm
if options[:osmName] == nil
	if ARGV.grep(/.osm/).any?
		temp=ARGV.grep /.osm/
		osm_name=temp[0]
	else
		puts "An OpenStudio OSM file must be indicated by the --osmNAME option or giving a filename ending with .osm on the command line"
		abort
	end
else  # otherwise the --osmName option was used
	osm_name = options[:osmName]
end

# if the user didn't give the --epwName option, parse the rest of the input arguments for a *.epw
if options[:epwName] == nil
	if ARGV.grep(/.epw/).any?
		temp=ARGV.grep /.epw/
		epw_name=temp[0]
	else
		puts "An .epw weather file must be indicated by the --epwNAME option or giving a filename ending with .epw on the command line"
		abort
	end
else  # otherwise the --epwName option was used
	epw_name = options[:epwName]
end

# strip the .osm from the OSM name to get the building name
building_name = osm_name[0..-5]

outfile_name = options[:outFile]
priors_name = options[:priorsFile]
num_of_runs = Integer(options[:numLHS])
verbose = options[:verbose]
skip_cleanup = options[:noCleanup]
randseed = Integer(options[:randseed])

# get the current working directory as the path
path = Dir.pwd

# expand filenames to full paths
osm_path = File.absolute_path(osm_name)     
epw_path = File.absolute_path(epw_name)
outfile_path = File.absolute_path(outfile_name)

#extract out just the base filename from the OSM file as the building name
building_name=File.basename(osm_name,".osm")

if not Dir.exist?("#{path}/PreRuns_Output")
	Dir.mkdir "#{path}/PreRuns_Output"
end


if File.exist?("#{outfile_path}")
	puts "Using Output Settings = #{outfile_path}" if verbose
	workbook = RubyXL::Parser.parse("#{outfile_path}")
    meters_table = Array.new
	meters_table_row = Array.new
	workbook['Meters'].each { |row|
		meters_table_row = []
		row.cells.each { |cell|     
			meters_table_row.push(cell.value)
		}
		meters_table.push(meters_table_row)	
	}
else
	puts "#{outfile_path}was NOT found!"
	abort
end

# check if .osm model exists and if so, load it
if File.exist?("#{osm_path}")
	model = OpenStudio::Model::Model::load(osm_path).get
	puts "Using OSM file #{osm_path}" if verbose
else
  puts "OpenStudio file #{osm_path} not found!"
  abort
end

# check if .epw exists
if File.exist?("#{epw_path}")
  puts "Using EPW file #{epw_path}" if verbose
else
  puts "Weather model #{epw_path} not found!"
  abort
end

# Generate LHS samples
lhs = LHSGenerator.new
input_path = "#{path}"
preruns_path = "#{path}/PreRuns_Output"

lhs.lhs_samples_generator(input_path, priors_name, num_of_runs, preruns_path, verbose, randseed)

samples = CSV.read("#{path}/PreRuns_Output/LHS_Samples.csv",headers:true)
parameter_names = []
parameter_types = []

samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end

uncertainty_parameters = UncertainParameters.new

priors_table = "#{path}/#{priors_name}"

for k in 2..samples[0].length-1
	parameter_value = []
  samples.each {|sample| parameter_value << sample[k].to_f}
  uncertainty_parameters.apply(model,parameter_types,parameter_names,parameter_value)
  # add reporting meters
	for meter_index in 1..(meters_table.length-1)
		meter = OpenStudio::Model::Meter.new(model)
    meter.setName("#{meters_table[meter_index][0]}")
    meter.setReportingFrequency("#{meters_table[meter_index][1]}")
	end
  variable = OpenStudio::Model::OutputVariable.new("Site Outdoor Air Drybulb Temperature", model)
  variable.setReportingFrequency("Monthly")
  variable = OpenStudio::Model::OutputVariable.new("Site Ground Reflected Solar Radiation Rate per Area", model)
  variable.setReportingFrequency("Monthly")

  # meters saved to sql file
  model.save("#{path}/PreRuns_Models/Sample#{k-1}.osm",true)
 
	# new edit start from here Yuna add for thermostat algorithm
	out_file_path_name_thermostat = "#{path}/PreRuns_Models/UQ_#{building_name}_thermostat.csv"
	model_output_path = "#{path}/PreRuns_Models/Sample#{k-1}.osm"
	uncertainty_parameters.thermostat_adjust(model,priors_table,out_file_path_name_thermostat,model_output_path,parameter_types,parameter_value)
  
  puts "Sample#{k-1} is saved to the folder of Models" if verbose
end

runner = RunOSM.new()
runner.run_osm("#{path}/PreRuns_Models",
               epw_path,
               "#{path}/PreRuns_Simulations",
               num_of_runs,
               verbose)

# Read Simulation Results
project_path = "#{path}"
OutPut.Read(num_of_runs,project_path,'PreRuns')

# clean up the temp files if skip cleanup not set
if !skip_cleanup
  File.delete("#{path}/PreRuns_Output/Random_LHS_Samples.csv") if File.exists?("#{path}/PreRuns_Output/Random_LHS_Samples.csv")
  FileUtils.remove_dir("#{path}/PreRuns_Models") if Dir.exists?("#{path}/PreRuns_Models")
end
## Prepare calibration input files
# # y_sim, Monthly Drybuld, Monthly Solar Horizontal, Calibration parameter samples...

y_sim = []
if File.exists?("#{path}/PreRuns_Output/Meter_Electricity_Facility.csv")
	y_elec_table = CSV.read("#{path}/PreRuns_Output/Meter_Electricity_Facility.csv",headers:false)
	y_elec_table.delete_at(0)
	y_elec_table.each do |run|
		run.each do |data|
			y_sim << data.to_f
		end
	end
end

if File.exists?("#{path}/PreRuns_Output/Meter_Gas_Facility.csv")
  y_gas_table = CSV.read("#{path}/PreRuns_Output/Meter_Gas_Facility.csv",headers:false)
  y_gas_table.delete_at(0)
  row = 0
  y_gas_table.each do |run|
		run.each do |data|
			y_sim[row] = [y_sim[row],data.to_f]
			row += 1
    end
  end
end

weather_table = CSV.read("#{path}/PreRuns_Output/Monthly_Weather.csv",headers:false)
weather_table.delete_at(0)
weather_table = weather_table.transpose
monthly_temp = weather_table[0]
monthly_solar = weather_table[1]

cal_parameter_samples_table = CSV.read("#{path}/PreRuns_Output/LHS_Samples.csv",headers:false)
cal_parameter_samples_table.delete_at(0)
cal_parameter_samples_table = cal_parameter_samples_table.transpose
cal_parameter_samples_table.delete_at(0)
cal_parameter_samples_table.delete_at(0)

cal_parameter_samples = []
cal_parameter_samples_table.each do |run|
	for rep in 1..12 # Monthly
		cal_parameter_samples << run
  end
end

cal_data_com = []
y_sim.each_with_index do |y,index|
  cal_data_com << y + [monthly_temp[index]] + [monthly_solar[index]] + cal_parameter_samples[index]
end

writeToFile(cal_data_com,"#{path}/PreRuns_Output/cal_sim_runs.txt", verbose)
FileUtils.cp "#{path}/PreRuns_Output/cal_sim_runs.txt", "#{path}/cal_sim_runs.txt"

utility_file=options[:utilityData]

# read in the utility meter data
y_meter = CSV.read("#{path}/#{utility_file}",headers:false)
y_meter.delete_at(0)
y_meter = y_meter.transpose
y_meter.delete_at(0)
y_meter = y_meter.transpose
puts "#{y_meter.length} months of data read from #{utility_file}" if verbose

# generate the cal_data_field as a table with columns of y_meter, monthly drybulb, monthly solar horizontal
cal_data_field = []
y_meter.each_with_index do |y,index|
	cal_data_field << y + [monthly_temp[index]] + [monthly_solar[index]]
end

puts "cal_data_field length = #{cal_data_field.length}" if verbose
writeToFile(cal_data_field,"#{path}/PreRuns_Output/cal_utility_data.txt")
FileUtils.cp "#{path}/PreRuns_Output/cal_utility_data.txt", "#{path}/cal_utility_data.txt"

puts "BC_Setup.rb Completed Successfully!"