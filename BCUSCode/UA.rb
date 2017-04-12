=begin comments
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
- Updates 27-mar-2017 by RTM to pass verbose to Uncertain_Parameters call
- Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
- Created on March 15 2015 by Yuming Sun from Argonne National Laboratory
- 02-Apr-2017: RTM: Added noEP option


1. Introduction
This is the main function of uncertainty analysis.

2. Call structure
Refer to 'Function Call Structure_UA.pptx'
=end

# use require_relative to include ruby functions developed in the project
# Run_All_OSMs.rb is developed by OpenStudio team at NREL

require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
#require_relative 'LHS_Gen'
require_relative 'LHS_Morris'
require_relative 'Process_Simulation_SQLs'

# use require to include functions from Ruby Library
require 'openstudio'
require 'csv'
require 'rubyXL'
require 'optparse'
require 'fileutils'

# define prompt to wait for user to enter y or Y to continue for interactive 
def wait_for_y
  check = 'n'
  while check != 'y' and check != 'Y'
    puts 'Please enter "Y" or "y" to continue, "n" or "N" or "CTRL-Z" to quit\n'
    #check = Readline.readline().squeeze(" ").strip.downcase
    # read from keyboard, strip leading and trailing spaces and convert to lower case
    check = $stdin.gets.strip.downcase
    if check == 'n'
      abort
    end
  end
end


# parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: UA.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('--osmName osmName', 'osmName') do |osmName|
    options[:osmName] = osmName
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('--epwName epwName', 'epwName') do |epwName|
    options[:epwName] = epwName
  end

  options[:interactive] = false
  opts.on('-i', '--interactive', 'run with interactive prompts to check setup files') do
    options[:interactive] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end

  options[:uqRepo] = 'Parameter UQ Repository V1.0.xlsx'
  opts.on('-u', '--uqRepo uqRepo', 'UQ Repository file (default "Parameter UQ Repositorty V1.0.xlsx")') do |uqRepo|
    options[:uqRepo] = uqRepo
  end

  options[:settingsFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-s', '--settingsfile outFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |settingsFile|
    options[:settingsFile] = settingsFile
  end

  # numLHS: the number of sample points of Monte Carlo simulation with Latin Hypercube Design
  # If not user specified, 500 will be used as the default.
  options[:numLHS] = 500
  opts.on('--numLHS numLHS', 'numLHS') do |numLHS|
    options[:numLHS] = numLHS
  end

  options[:randseed] = 0
  opts.on('--seed seednum', 'Integer random number seed, 0 = no seed, default = 0') do |seednum|
    options[:randseed] = seednum
  end

  options[:verbose] = false
  opts.on('-v', '--verbose', 'Run in verbose mode with more output info printed') do 
    options[:verbose] = true
  end
  
  options[:noep] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noEP] = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end
parser.parse!

if options[:osmName] == nil
  if ARGV.grep(/.osm/).any?
    temp=ARGV.grep /.osm/
    osm_name=temp[0]
  else
    puts 'An OpenStudio OSM file must be indicated by the --osmNAME option or giving a filename ending with .osm on the command line'
    abort
  end
else # otherwise the --osmName option was used
  osm_name = options[:osmName]
end

# if the user didn't give the --epwName option, parse the rest of the input arguments for a *.epw
if options[:epwName] == nil
  if ARGV.grep(/.epw/).any?
    temp=ARGV.grep /.epw/
    epw_name=temp[0]
  else
    puts 'An .epw weather file must be indicated by the --epwNAME option or giving a filename ending with .epw on the command line'
    abort
  end
else # otherwise the --epwName option was used
  epw_name = options[:epwName]
end

verbose = options[:verbose]
uqrepo_name = options[:uqRepo]
outfile_name = options[:settingsFile]
settingsfile_name = options[:settingsFile]
run_interactive = options[:interactive]
skip_cleanup = options[:noCleanup]
num_LHS_runs = Integer(options[:numLHS])
randseed = Integer(options[:randseed])
noEP = options[:noEP]

# if we are choosing noEP we also want to skip cleanup even if it hasn't been selected
if noEP
  skip_cleanup = true
end

if run_interactive
  puts 'Running Interactively'
  wait_for_y
end

puts 'Not Cleaning Up Interim Files' if (skip_cleanup && verbose)

# Acquire the path of the working directory that is the user's project folder.
path = Dir.pwd

# expand filenames to full paths
osm_path = File.absolute_path(osm_name)
epw_path = File.absolute_path(epw_name)
uqrepo_path = File.absolute_path(uqrepo_name)
outfile_path = File.absolute_path(outfile_name)
settingsfile_path = File.absolute_path(settingsfile_name)

#extract out just the base filename from the OSM file as the building name
building_name=File.basename(osm_name, '.osm')

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

Dir.mkdir "#{path}/UA_Output" unless Dir.exist?("#{path}/UA_Output")

# Load UQ repository
if File.exist?("#{uqrepo_path}")
  puts "Using UQ repository = #{uqrepo_path}" if verbose
  workbook = RubyXL::Parser.parse("#{uqrepo_path}")
  uq_table = Array.new
  uq_table_row = Array.new
  workbook['UQ'].each { |row|
    uq_table_row = []
    row.cells.each { |cell|
      uq_table_row.push(cell.value)
    }
    uq_table.push(uq_table_row)
  }
else
  puts "#{uqrepo_path} was NOT found!"
  abort
end

if File.exist?("#{settingsfile_path}")
  puts "Using Output Settings = #{settingsfile_path}" if verbose
  workbook = RubyXL::Parser.parse("#{settingsfile_path}")
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
  puts "#{settingsfile_path} was NOT found!"
  abort
end

if verbose
  puts "Using Number of LHS samples  = #{num_LHS_runs}"
  puts "Using Random Seed = #{randseed}"
end

# remove the header rows
(1..2).each { |i|
  uq_table.delete_at(0)
}

# Define the output path of building specific uncertainty table
out_file_path_name = "#{path}/UA_Output/UQ_#{building_name}.csv"
uncertainty_parameters = UncertainParameters.new
uncertainty_parameters.find(model, uq_table, out_file_path_name, verbose)

if run_interactive
  puts "Check the #{path}/UA_Output/UQ_#{building_name}.csv"
  wait_for_y
end

uqtablefilePath = "#{path}/UA_Output"
outputfilePath = "#{path}/UA_Output"

# Generate LHS samples
lhs = LHSGenerator.new
lhs.lhs_samples_generator(uqtablefilePath, 'UQ_'+ building_name + '.csv', num_LHS_runs, outputfilePath, verbose, randseed)

samples = CSV.read("#{path}/UA_Output/LHS_Samples.csv", headers: true)
parameter_names = []
parameter_types = []

samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end

uncertainty_parameters = UncertainParameters.new

if run_interactive
  puts "Going to run #{num_LHS_runs} models.  This could take a while"
  wait_for_y
end


if noEP
  if verbose
    puts
    puts '--noEP option selected, skipping generation of OpenStudio files and running of EnergyPlus'
    puts
  end
else
  (2..samples[0].length-1).each { |k|
    model = OpenStudio::Model::Model::load(osm_path).get # reload the model to get the same starting point each time
    parameter_value = []
    samples.each { |sample| parameter_value << sample[k].to_f }
    uncertainty_parameters.apply(model, parameter_types, parameter_names, parameter_value)
    # add reporting meters
    (1..(meters_table.length-1)).each { |meter_index|
      meter = OpenStudio::Model::Meter.new(model)
      meter.setName("#{meters_table[meter_index][0]}")
      meter.setReportingFrequency("#{meters_table[meter_index][1]}")
    }
    variable = OpenStudio::Model::OutputVariable.new('Site Outdoor Air Drybulb Temperature', model)
    variable.setReportingFrequency('Monthly')
    variable = OpenStudio::Model::OutputVariable.new('Site Ground Reflected Solar Radiation Rate per Area', model)
    variable.setReportingFrequency('Monthly')
    # meters saved to sql file
    model.save("#{path}/UA_Models/Sample#{k-1}.osm", true)

    # new edit start from here Yuna add for thermostat algorithm
    out_file_path_name_thermostat = "#{path}/UA_Output/UQ_#{building_name}_thermostat.csv"
    model_output_path = "#{path}/UA_Models/Sample#{k-1}.osm"
    uncertainty_parameters.thermostat_adjust(model, uq_table, out_file_path_name_thermostat, model_output_path, parameter_types, parameter_value)

    puts "Sample#{k-1} is saved to the folder of Models" if verbose
  }

  # run all the OSM simulation files 
  runner = RunOSM.new
  runner.run_osm("#{path}/UA_Models", epw_path, "#{path}/UA_Simulations", num_LHS_runs, verbose)
end

# Read Simulation Results
project_path = "#{path}"
OutPut.Read(num_LHS_runs, project_path, 'UA',  settingsfile_path, verbose)

#delete intermediate files
unless skip_cleanup
  File.delete("#{path}/UA_Output/Monthly_Weather.csv") if File.exists?("#{path}/UA_Output/Monthly_Weather.csv")
  FileUtils.remove_dir("#{path}/UA_Models") if Dir.exists?("#{path}/UA_Models")
end

puts 'UA.rb Completed Successfully!' if verbose