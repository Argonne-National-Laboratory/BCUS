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
#       "This product includes software produced by UChicago Argonne, LLC under
#       Contract No. DE-AC02-06CH11357 with the Department of Energy."

# ******************************************************************************
# DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY
# FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA,
# APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT
# INFRINGE PRIVATELY OWNED RIGHTS.

# ******************************************************************************

# 1. Introduction
# This is the main function of analysis.

# 2. Call structure

# Use require to include functions from Ruby Library
require 'fileutils'
require 'csv'
require 'optparse'
require 'rubyXL'
require 'rinruby'
require 'openstudio'

# Use require_relative to include ruby functions developed in the project
require_relative 'Uncertain_Parameters'
require_relative 'LHD_gen'
require_relative 'morris'
require_relative 'run_all_osms'
require_relative 'read_simulation_results_sql'

# Define prompt to wait for user to enter y or Y to continue for interactive
def wait_for_y
  check = 'n'
  while check != 'y' && check != 'Y'
    puts 'Please enter "Y" or "y" to continue, "n" or "N" or "CTRL-Z" to quit:'
    # Read from keyboard, strip leading and trailing spaces and convert to
    # lowercase
    check = $stdin.gets.strip.downcase
    abort if check == 'n'
  end
end

def write_to_file(results, filename, verbose = false)
  File.open(filename, 'w+') do |f|
    results.each do |results_row|
      results_row.each do |r|
        f.write(r)
        f.write("\t")
      end
      f.write("\n")
    end
  end
  puts "Run results have been written to #{filename}" if verbose
end

# Parse command line inputs from the user
options = {:osmName => nil, :epwName => nil, :runType => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: run_analysis.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('--osmName osmName', 'Name of .osm file to run') do |osm_name|
    options[:osmName] = osm_name
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('--epwName epwName', 'Name of .epw weather file to use') do |epw_name|
    options[:epwName] = epw_name
  end

  # runType: Type of analysis
  opts.on('--runType runType', 'Type of analysis') do |run_type|
    options[:runType] = run_type
  end

  options[:interactive] = false
  opts.on(
    '-i', '--interactive', 'Run with interactive prompts to check setup files.'
  ) do
    options[:interactive] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files.') do
    options[:noCleanup] = true
  end

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on(
    '-o', '--outFile outFile',
    'Simulation output setting file, default "Simulation_Output_Settings.xlsx"'
  ) do |out_file|
    options[:outFile] = out_file
  end

  options[:numLHD] = 500
  opts.on(
    '--numLHD numLHD',
    'Number of sample points of Monte Carlo simulation' \
    'with Latin Hypercube Design sampling, default 500'
  ) do |num_lhd|
    options[:numLHD] = num_lhd
  end

  options[:morrisR] = 5
  opts.on(
    '--morrisR morrisR', 'Number of repetitions for morris method, default 5'
  ) do |morris_r|
    options[:morrisR] = morris_r
  end

  options[:morrisL] = 20
  opts.on(
    '--morrisL morrisL',
    'Number of levels for each parameter for morris method, default 20'
  ) do |morris_l|
    options[:morrisL] = morris_l
  end

  options[:uqRepo] = 'Parameter UQ Repository V1.0.xlsx'
  opts.on(
    '-u', '--uqRepo uqRepo',
    'UQ repository file, default "Parameter UQ Repositorty V1.0.xlsx"'
  ) do |uq_repo|
    options[:uqRepo] = uq_repo
  end

  options[:priorsFile] = 'Parameter Priors.csv'
  opts.on(
    '--priors priorsFile',
    'Prior uncertainty information file, default "Parameter Priors.csv"'
  ) do |priors_file|
    options[:priorsFile] = priors_file
  end

  options[:utilityData] = 'Utility Data.csv'
  opts.on(
    '--utilityData utilityData',
    'Utility data file, default "Utility Data.csv"'
  ) do |utility_data|
    options[:utilityData] = utility_data
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
    'Integer random number seed, 0 = no seed, default 0'
  ) do |seednum|
    options[:randseed] = seednum
  end

  options[:verbose] = false
  opts.on(
    '-v', '--verbose', 'Run in verbose mode with more output info printed'
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
    puts 'An OpenStudio OSM file must be indicated by the --osmNAME option' \
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
    puts 'An .epw weather file must be indicated by the --epwNAME option' \
         'or giving a filename ending with .epw on the command line'
    abort
  end
else # Otherwise the --epwName option was used
  epw_name = options[:epwName]
end

# Assign analysis settings
run_type = options[:runType]
outfile_name = options[:outFile]
run_interactive = options[:interactive]
verbose = options[:verbose]
skip_cleanup = options[:noCleanup]
num_processes = Integer(options[:numProcesses])
randseed = Integer(options[:randseed])

case run_type
when 'UA'
  puts 'Running uncertainty analysis' if verbose
  uqrepo_name = options[:uqRepo]
  num_lhd_runs = Integer(options[:numLHD])
when 'SA'
  puts 'Running sensitivity analysis' if verbose
  uqrepo_name = options[:uqRepo]
  morris_reps = Integer(options[:morrisR])
  morris_levels = Integer(options[:morrisL])
when 'BC_Setup'
  num_lhd_runs = Integer(options[:numLHD])
  priors_name = options[:priorsFile]
else
  puts 'Unrecognized analysis type'
  abort
end

if run_interactive
  puts 'Running interactively'
  wait_for_y
end

puts 'Not cleaning up interim files' if skip_cleanup

# Extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_name, '.osm')

# Check if .osm model exists and if so, load it
osm_path = File.absolute_path(osm_name)
if File.exist?(osm_path)
  model = OpenStudio::Model::Model.load(osm_path).get
  puts "Using OSM file #{osm_path}" if verbose
else
  puts "OpenStudio file #{osm_path} not found!"
  abort
end

# Check if .epw exists and if so, load it
epw_path = File.absolute_path(epw_name)
if File.exist?(epw_path)
  puts "Using EPW file #{epw_path}" if verbose
else
  puts "Weather model #{epw_path} not found!"
  abort
end

# Check if output file exist and if so, load it
outfile_path = File.absolute_path(outfile_name)
if File.exist?(outfile_path)
  puts "Using output settings = #{outfile_path}" if verbose
  workbook = RubyXL::Parser.parse(outfile_path)
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

# Check if UQ repository file exist and if so, load it
unless run_type == 'BC_Setup'
  uqrepo_path = File.absolute_path(uqrepo_name)
  if File.exist?(uqrepo_path)
    puts "Using UQ repository = #{uqrepo_path}" if verbose
    workbook = RubyXL::Parser.parse(uqrepo_path)
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

  # Remove the header rows
  2.times { uq_table.delete_at(0) }
end

if verbose
  case run_type
  when 'UA', 'BC_Setup'
    puts "Using number of LHD samples  = #{num_lhd_runs}"
  when 'SA'
    puts "Using morris repetitions = #{morris_reps}"
    puts "Using morris levels = #{morris_levels}"
  end
  puts "Using number of parallel processes  = #{num_processes}"
  puts "Using random seed = #{randseed}"
end

# Acquire the path of the working directory that is the user's project folder
path = Dir.pwd
model_dir = "#{path}/#{run_type}_Model"
sim_dir = "#{path}/#{run_type}_Simulations"
output_dir = "#{path}/#{run_type}_Output"

Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

# Step 1: Generate uncertainty parameters distributions
uq_file_path = "#{output_dir}/UQ_#{building_name}.csv"
uncertainty_parameters = UncertainParameters.new
uncertainty_parameters.find(model, uq_table, uq_file_path, verbose)

if run_interactive
  puts "Check the #{uq_file_path}"
  wait_for_y
end

case run_type
when 'UA'
  # Generate LHS samples
  lhs = LHSGenerator.new
  lhs.lhs_samples_generator(
    uq_file_path, num_lhd_runs, output_dir, randseed, verbose
  )
  sample_file_name = 'LHD_Sample.csv'
when 'SA'
  morris = Morris.new
  morris.design_matrix_generator(
    uq_file_path, morris_reps, morris_levels, output_dir, randseed
  )
  sample_file_name = 'Morris_CDF_Tran_Design.csv'
end

samples = CSV.read("#{output_dir}/#{sample_file_name}", headers: true)
parameter_names = []
parameter_types = []

samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end
num_runs = samples[0].length - 2

if run_interactive
  puts "Going to run #{num_runs} models.  This could take a while"
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
  model.save("#{model_dir}/Sample#{k - 1}.osm", true)

  # New edit start from here Yuna add for thermostat algorithm
  out_file_path_name_thermostat =
    "#{output_dir}/UQ_#{building_name}_thermostat.csv"
  model_output_path = "#{model_dir}/Sample#{k - 1}.osm"
  uncertainty_parameters.thermostat_adjust(
    model, uq_table, out_file_path_name_thermostat, model_output_path,
    parameter_types, parameter_value
  )

  puts "Sample#{k - 1} is saved to the folder of Models" if verbose
end

# Run all the OSM simulation files
runner = RunOSM.new
runner.run_osm(model_dir, epw_path, sim_dir, num_processes, verbose)

# Read simulation results
OutPut.read(num_runs, path, run_type, verbose)
if run_type == 'SA'
  morris.compute_sensitivities(
    "#{output_dir}/Simulation_Results_Building_Total_Energy.csv",
    uq_file_path, output_dir
  )
end

# Delete intermediate files
unless skip_cleanup
  FileUtils.remove_dir(model_dir) if Dir.exist?(model_dir)
  clean_names = [
    'Monthly_Weather.csv',
    'Meter_Electricity.csv',
    'Meter_Gas.csv'
  ]
  if run_type == 'SA'
    clean_names.push('Morris_0_1_Design.csv')
    clean_names.push('Morris_CDF_Tran_Design.csv')
    clean_names.push('Simulation_Results_Building_Total_Energy.csv')
  end
  clean_names.each do |file|
    File.delete("#{output_dir}/#{file}") if File.exist?("#{output_dir}/#{file}")
  end
end

puts "#{run_type} completed successfully!"
