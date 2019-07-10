# Copyright © 2019 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.  Software changes,
#    modifications, or derivative works, should be noted with comments and the
#    author and organization's name.

# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.

# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor
#    the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.

# 4. The software and the end-user documentation included with the
#    redistribution, if any, must include the following acknowledgment:

#    "This product includes software produced by UChicago Argonne, LLC under
#     Contract No. DE-AC02-06CH11357 with the Department of Energy."

# ******************************************************************************
# DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

# ******************************************************************************

# Modified Date and By:
# - Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
# - Created on March 15 2015 by Yuming Sun from Argonne National Laboratory

# 1. Introduction
# This is the main function of uncertainty analysis.

# 2. Call structure
# Refer to 'Function Call Structure_UA.pptx'

# Use require to include functions from Ruby Library
require 'openstudio'
require 'csv'
require 'rubyXL'
require 'optparse'
require 'fileutils'

# Use require_relative to include ruby functions developed in the project
require_relative 'run_all_osms'
require_relative 'Uncertain_Parameters'
require_relative 'LHD_gen'
require_relative 'read_simulation_results_sql'

# Define prompt to wait for user to enter y or Y to continue for interactive
def wait_for_y
  check = 'n'
  while check != 'y' && check != 'Y'
    puts 'Please enter "Y" or "y" to continue, "n" or "N" or "CTRL-Z" to quit:'
    # Read from keyboard, strip leading and trailing spaces and convert to lower
    # case
    # check = Readline.readline().squeeze(" ").strip.downcase
    check = $stdin.gets.strip.downcase
    abort if check == 'n'
  end
end

# Parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: UA.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('--osmName osmName', 'osmName') do |osm_name|
    options[:osmName] = osm_name
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('--epwName epwName', 'epwName') do |epw_name|
    options[:epwName] = epw_name
  end

  options[:interactive] = false
  opts.on(
    '-i', '--interactive', 'run with interactive prompts to check setup files'
  ) do
    options[:interactive] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end

  options[:uqRepo] = 'Parameter_UQ_Repository_V1.0.xlsx'
  opts.on(
    '-u', '--uqRepo uqRepo',
    'UQ Repository file (default "Parameter UQ Repositorty V1.0.xlsx")'
  ) do |uq_repo|
    options[:uqRepo] = uq_repo
  end

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on(
    '-o', '--outfile outFile',
    'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")'
  ) do |out_file|
    options[:outFile] = out_file
  end

  # numLHS: the number of sample points of Monte Carlo simulation with Latin
  # Hypercube Design
  # If not user specified, 500 will be used as the default.
  options[:numLHS] = 500
  opts.on('--numLHS numLHS', 'numLHS') do |num_lhs|
    options[:numLHS] = num_lhs
  end

  options[:numProcesses] = 0
  opts.on(
    '--numProcesses numProcesses',
    'Number of parallel processes for simulation, 0 = no parallel, default 0'
  ) do |n_processes|
    options[:numProcesses] = n_processes
  end

  options[:randseed] = 0
  opts.on(
    '--seed seednum',
    'Integer random number seed, 0 = no seed, default = 0'
  ) do |seednum|
    options[:randseed] = seednum
  end

  options[:verbose] = false
  opts.on(
    '-v', '--verbose',
    'Run in verbose mode with more output info printed'
  ) do
    options[:verbose] = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end
parser.parse!

# If the user didn't give the --osmName option, parse the rest of the input
# arguments for a *.osm
if options[:osmName].nil?
  if ARGV.grep(/.osm/).any?
    temp = ARGV.grep(/.osm/)
    osm_name = temp[0]
  else
    puts 'An OpenStudio OSM file must be indicated by the --osmNAME option ' \
         'or giving a filename ending with .osm on the command line'
    abort
  end
else # Otherwise the --osmName option was used
  osm_name = options[:osmName]
end

# If the user didn't give the --epwName option, parse the rest of the input
# arguments for a *.epw
if options[:epwName].nil?
  if ARGV.grep(/.epw/).any?
    temp = ARGV.grep(/.epw/)
    epw_name = temp[0]
  else
    puts 'An .epw weather file must be indicated by the --epwNAME option ' \
         'or giving a filename ending with .epw on the command line'
    abort
  end
else # Otherwise the --epwName option was used
  epw_name = options[:epwName]
end

verbose = options[:verbose]
uqrepo_name = options[:uqRepo]
outfile_name = options[:outFile]
run_interactive = options[:interactive]
skip_cleanup = options[:noCleanup]
num_lhs_runs = Integer(options[:numLHS])
num_processes = Integer(options[:numProcesses])
randseed = Integer(options[:randseed])

if run_interactive
  puts 'Running Interactively'
  wait_for_y
end

puts 'Not Cleaning Up Interim Files' if skip_cleanup

# Acquire the path of the working directory that is the user's project folder.
path = Dir.pwd

# Expand filenames to full paths
osm_path = File.absolute_path(osm_name)
epw_path = File.absolute_path(epw_name)
uqrepo_path = File.absolute_path(uqrepo_name)
outfile_path = File.absolute_path(outfile_name)

# Extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_name, '.osm')

# Check if .osm model exists and if so, load it
if File.exist?(osm_path.to_s)
  model = OpenStudio::Model::Model.load(osm_path).get
  puts "Using OSM file #{osm_path}" if verbose
else
  puts "OpenStudio file #{osm_path} not found!"
  abort
end

# Check if .epw exists
if File.exist?(epw_path.to_s)
  puts "Using EPW file #{epw_path}" if verbose
else
  puts "Weather model #{epw_path} not found!"
  abort
end

# Load UQ repository
if File.exist?(uqrepo_path.to_s)
  puts "Using UQ repository = #{uqrepo_path}" if verbose
  workbook = RubyXL::Parser.parse(uqrepo_path.to_s)
  uq_table = []
  uq_table_row = []
  workbook['UQ'].each do |row|
    uq_table_row = []
    row.cells.each { |cell| uq_table_row.push(cell.value) }
    uq_table.push(uq_table_row)
  end
else
  puts "#{uqrepo_path} was NOT found!"
  abort
end

if File.exist?(outfile_path.to_s)
  puts "Using Output Settings = #{outfile_path}" if verbose
  workbook = RubyXL::Parser.parse(outfile_path.to_s)
  meters_table = []
  meters_table_row = []
  workbook['Meters'].each do |row|
    meters_table_row = []
    row.cells.each { |cell| meters_table_row.push(cell.value) }
    meters_table.push(meters_table_row)
  end
else
  puts "#{outfile_path} was NOT found!"
  abort
end

if verbose
  puts "Using Number of LHS samples  = #{num_lhs_runs}"
  puts "Using Random Seed = #{randseed}"
end

# Remove the header rows
2.times { uq_table.delete_at(0) }

Dir.mkdir("#{path}/UA_Output") unless Dir.exist?("#{path}/UA_Output")

puts 'Step 1: Generate uncertainty parameters distributions' if verbose

# Define the output path of building specific uncertainty table
uq_file_path = "#{path}/UA_Output/UQ_#{building_name}.csv"
uncertainty_parameters = UncertainParameters.new
uncertainty_parameters.find(model, uq_table, uq_file_path, verbose)

if run_interactive
  puts "Check the #{path}/UA_Output/UQ_#{building_name}.csv"
  wait_for_y
end

output_file_dir = "#{path}/UA_Output"

# Generate LHS samples
lhs = LHSGenerator.new
lhs.lhd_samples_generator(
  uq_file_path, num_lhs_runs, output_file_dir, randseed, verbose
)

samples = CSV.read("#{path}/UA_Output/LHD_Sample.csv", headers: true)
parameter_names = []
parameter_types = []
samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end

# Wait_for_y if run_interactive
if run_interactive
  puts "Going to run #{num_lhs_runs} models.  This could take a while"
  wait_for_y
end

(2..samples[0].length - 1).each do |k|
  model = OpenStudio::Model::Model.load(osm_path).get
  parameter_value = []
  samples.each { |sample| parameter_value << sample[k].to_f }
  uncertainty_parameters.apply(
    model, parameter_types, parameter_names, parameter_value
  )
  # Add reporting meters
  (1..(meters_table.length - 1)).each do |meter_index|
    meter = OpenStudio::Model::OutputMeter.new(model)
    meter.setName(meters_table[meter_index][0].to_s)
    meter.setReportingFrequency(meters_table[meter_index][1].to_s)
  end
  variable = OpenStudio::Model::OutputVariable.new(
    'Site Outdoor Air Drybulb Temperature', model
  )
  variable.setReportingFrequency('Monthly')
  variable = OpenStudio::Model::OutputVariable.new(
    'Site Ground Reflected Solar Radiation Rate per Area', model
  )
  variable.setReportingFrequency('Monthly')
  # Meters saved to sql file
  model.save("#{path}/UA_Models/Sample#{k - 1}.osm", true)

  # New edit start from here Yuna add for thermostat algorithm
  out_file_path_name_thermostat =
    "#{path}/UA_Output/UQ_#{building_name}_thermostat.csv"
  model_output_path = "#{path}/UA_Models/Sample#{k - 1}.osm"
  uncertainty_parameters.thermostat_adjust(
    model, uq_table, out_file_path_name_thermostat, model_output_path,
    parameter_types, parameter_value
  )

  puts "Sample#{k - 1} is saved to the folder of Models" if verbose
end

# Run all the OSM simulation files
runner = RunOSM.new
runner.run_osm(
  "#{path}/UA_Models", epw_path, "#{path}/UA_Simulations",
  num_lhs_runs, num_processes
)

# Read simulation results
result_paths = []
(1..num_lhs_runs).each do |sample_num|
  result_paths.push(
    "#{path}/UA_Simulations/Sample#{sample_num}/run/eplusout.sql"
  )
end
output_folder = "#{path}/UA_Output"
OutPut.read(result_paths, outfile_path, output_folder, false, verbose)

# Delete intermediate files
unless skip_cleanup
  FileUtils.remove_dir("#{path}/UA_Models") if Dir.exist?("#{path}/UA_Models")
  clean_path = "#{path}/UA_Output/Random_LHD_Samples.csv"
  File.delete(clean_path) if File.exist?(clean_path)
end

puts 'UA.rb Completed Successfully!'
