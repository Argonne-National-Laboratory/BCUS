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
# - August 2016 by Yuna Zhang
# - Created on Feb 15 2015 by Yuming Sun from Argonne National Laboratory

# 1. Introduction
# This is the main code used for running Bayesian calibration to generate
# posterior distributions and graphing results

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'

#===============================================================%
#     author: Yuming Sun and Matt Riddle                        %
#     date: Feb 27, 2015                                        %
#===============================================================%

# Main code used for running Bayesian calibration to generate posterior
# distributions and graphing results
#

# CALLS: bCRunner.rb, graphGenerator.rb

#==============================================================#
#                        REQUIRED INPUTS                       #
#==============================================================#
# the following input files must have been created in the input
#   folder for the project before running this:
#
# Calibration_Parameters_Prior.csv: file with info on parameter prior
# distributions
#   first column: Parameter Type
#   second column: Object in the model
#   third column: Parameter Base Value (for relative distributions)
#   fourth column: Distribution
#   fifth column: Mean or Mode
#   sixth column: Std Dev
#   seventh column: Min
#   eigth column: Max
#
#  COMMENTS: some columns may be left blank, depending on the distribution type
#
# cal_data_com.txt: file with results of computer model runs
#   first columns (# columns specified in numOutVars): model output
#   next columns (# columns specified in numWVars):
#     values for x (e.g., weather) variables used in model runs
#   remaining columns (# columns should match # rows in params_filename):
#     values for theta parameters used in model runs
#
# cal_data_field.txt: file with observed data used for calibration
#   first columns (# columns specified in numYVars): observed output
#   next columns: observed x (e.g., weather) data
#
#==============================================================#
# in addition, the following options should be specified when
# this is called from Ruby:
# projectName: name of project
# used to name folders for storing inputs and outputs
# numMCMC: the number of steps to run the mcmc algorithm for
# numOutVars = number of y (output) variables in input files
# numWVars = number of x (e.g., weather) variables in input files
# numBurnin: number of steps from mcmc results to be discarded
#   before showing posterior distributions
# osmName:
# epwName:
#
# an example of how to call it is:
#   ruby -S BC.rb test.osm test.epw --numMCMC 3000 --numbBurnin 30

#===============================================================#
#                           OUTPUTS                             #
#===============================================================#
# results will be saved to the files to the output:
#   posterior_dists.csv: posterior realizations (nmcmc x num parameters)
#   PosteriorVsPrior1.pdf ... posteriorVsPriorN.pdf (N = numTheta)
#   a set of histograms, one per parameter, showing posterior
#       distributions for the parameter compared against its prior
#       distribution
#   posteriorScatterPlotsV1.pdf and posteriorScatterPlotsV2.pdf
#   two versions of a matrix of graphs with the diagonal
#   matrices showing posterior distributions for each
#   parameter and the off-diagonal showing scatter plots
#   of the joint distributions for each pair of parameters
#   These will be generated only if 2 <= numTheta <= 6
#
#===============================================================%
# $LOAD_PATH.unshift('/Applications/OpenStudio 1.5.0/Ruby')
# $: << File.join(File.dirname(__FILE__))

# Load in the required ruby libraries
require 'fileutils'
require 'csv'
require 'optparse'
require 'openstudio'

# Load in our own libraries
require_relative 'graphGenerator'
require_relative 'BCRunner'
require_relative 'run_all_osms'
require_relative 'Uncertain_Parameters'
require_relative 'read_simulation_results_sql'

def average(one_d_array)
  sum = 0.0
  n = one_d_array.length
  one_d_array.each do |val|
    begin
      Float(val)
    rescue StandardError
      n -= 1
    else
      sum += val
    end
  end
  return sum / n
end

# Parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: Bayesian_Calibration.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('--osmName osmName', 'Name of .osm file to run') do |osm_name|
    options[:osmName] = osm_name
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('--epwName epwName', 'Name of .epw weather file to use') do |epw_name|
    options[:epwName] = epw_name
  end

  options[:comFile] = 'cal_sim_runs.txt'
  opts.on(
    '--comFile comFile',
    'Filename of simulation outputs (default = "cal_sim_runs.txt")'
  ) do |com_file|
    options[:comFile] = com_file
  end

  options[:fieldFile] = 'cal_utility_data.txt'
  opts.on(
    '--fieldFile fieldFile',
    'Filename of utility data for comparison (default = "cal_utility_data.txt")'
  ) do |field_file|
    options[:fieldFile] = field_file
  end

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on(
    '-o', '--outFile outFile',
    'Simulation output setting file, default "Simulation_Output_Settings.xlsx"'
  ) do |out_file|
    options[:outFile] = out_file
  end

  options[:numMCMC] = 30_000
  opts.on(
    '--numMCMC numMCMC', 'Number of MCMC steps (default = 30000)'
  ) do |num_mcmc|
    options[:numMCMC] = num_mcmc
  end

  options[:numOutVars] = 1
  opts.on(
    '--numOutVars numOutVars',
    'Number of output variables, 1 or 2 (default = 1)'
  ) do |num_out_vars|
    options[:numOutVars] = num_out_vars
  end
  options[:numWVars] = 2
  opts.on(
    '--numWVars numWVars', 'Number of weather variables (default = 2)'
  ) do |num_w_vars|
    options[:numWVars] = num_w_vars
  end

  options[:numBurnin] = 500
  opts.on(
    '--numBurnin numBurnin',
    'Number of burning samples to throw out (default = 500)'
  ) do |num_burnin|
    options[:numBurnin] = num_burnin
  end

  options[:priorsFile] = 'Parameter Priors.csv'
  opts.on(
    '--priors priorsFile',
    'Prior uncertainty information file, default "Parameter Priors.csv"'
  ) do |priors_file|
    options[:priorsFile] = priors_file
  end

  options[:postsFile] = 'Parameter Posteriors.csv'
  opts.on(
    '--postsFile postsFile',
    'Filename of posterior distributions (default = "Parameter Posteriors.csv")'
  ) do |posts_file|
    options[:postsFile] = posts_file
  end

  options[:pvalsFile] = 'pvals.csv'
  opts.on(
    '--pvalsFile pvalsFile', 'Filename of pvals (default = "pvals.csv")'
  ) do |pvals_file|
    options[:pvalsFile] = pvals_file
  end

  options[:randseed] = 0
  opts.on(
    '--seed seednum',
    'Integer random number seed, 0 = no seed, default 0'
  ) do |seednum|
    options[:randseed] = seednum
  end

  options[:noRunCal] = false
  opts.on('--noRunCal', 'Do not run the calibrated model when complete') do
    options[:noRunCal] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files.') do
    options[:noCleanup] = true
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

# Assign analysis settings
priors_name = options[:priorsFile]
cal_data_com_name = options[:comFile]
cal_data_field_name = options[:fieldFile]
posts_name = options[:postsFile]
pvals_name = options[:pvalsFile]
outfile_name = options[:outFile]
num_mcmc = Integer(options[:numMCMC])
num_out_vars = Integer(options[:numOutVars])
num_w_vars = Integer(options[:numWVars])
num_burnin = Integer(options[:numBurnin])
randseed = Integer(options[:randseed])
no_run_cal = options[:noRunCal]
skip_cleanup = options[:noCleanup]
verbose = options[:verbose]

if verbose
  puts 'Running Bayesian calibration of computer models'
  puts "Using number of output variables = #{num_out_vars}"
  puts "Using number of weather variables = #{num_w_vars}"
  puts "Using number of MCMC sample points = #{num_mcmc}"
  puts "Using number of burn-in sample points = #{num_burnin}"
  puts "Using random seed = #{randseed}"
  puts 'Not cleaning up interim files' if skip_cleanup
end

# Extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_name, '.osm')

# Check if .osm model exists and if so, load it
osm_path = File.absolute_path(osm_name)
if File.exist?(osm_path)
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

if verbose
  puts "Generating posterior values file = #{posts_name}"
  puts "Generating pvals file = #{pvals_name}"
end

## Main process
# Require the following files from parametric simulations
# Parameters Prior.csv
# cal_data_field.txt
# cal_data_com.txt

# LHD design is used now
# Space filling design could be adopted later

# cal_data_com.txt: Computation data
# In the order of: Monthly Energy Output;
#                  Monthly Dry-bulb Temperature (C),
#                  Monthly Global Horizontal Solar Radiation (W/M2)
#                  Calibration Parameters

# cal_data_field.txt: Observed data
# In the order of: Monthly Energy Output;
#                  Monthly Dry-bulb Temperature (C),
#                  Monthly Global Horizontal Solar Radiation (W/M2)

# Acquire the path of the working directory that is the user's project folder
path = Dir.pwd
cal_output_path = "#{path}/Calibration_Output/"
posts_path = "#{cal_output_path}/#{posts_name}"
pvals_filename = "#{cal_output_path}/#{pvals_name}"
graphs_output_folder = "#{cal_output_path}/"
Dir.mkdir(cal_output_path) unless Dir.exist?(cal_output_path)

# Check if priors file exists
priors_path = File.absolute_path(priors_name)
if File.exist?(priors_path)
  puts "Using priors csv file #{priors_path}" if verbose
else
  puts "Priors file #{priors_path} not found!"
  abort
end

# Check if COM file exists
cal_data_com_path = File.absolute_path(cal_data_com_name)
if File.exist?(cal_data_com_path)
  puts "Using simulation output file = #{cal_data_com_path}" if verbose
else
  puts "com.txt file #{cal_data_com_path} not found!"
  abort
end

# Check if FIELD file exists
cal_data_field_path = File.absolute_path(cal_data_field_name)
if File.exist?(cal_data_field_path)
  puts "Using utility data file = #{cal_data_field_path}" if verbose
else
  puts "field.txt file #{cal_data_field_path} not found!"
  abort
end

# Perform Bayesian calibration
code_path = ENV['BCUSCODE']
puts "Using code path = #{code_path}\n\r" if verbose
BCRunner.run_bc(
  code_path, priors_path, cal_data_com_path, cal_data_field_path,
  num_out_vars, num_w_vars, num_mcmc,
  pvals_filename, posts_path, verbose, randseed
)

if num_burnin >= num_mcmc
  puts 'Warning: numBurnin should be less than numMCMC. ' \
       "numBurnin has been reset to 0.\n"
  num_burnin = 0
end

puts 'Generating posterior distribution plots' if verbose
# Could pass in graph file names too
GraphGenerator.graphPosteriors(
  priors_path, pvals_filename, num_burnin, graphs_output_folder
)

# Run calibrated model
unless no_run_cal
  puts "\nGenerate and run calibrated model" if verbose

  cal_model_folder = "#{path}/Calibrated_Model"
  cal_model_name = "Calibrated_#{building_name}"

  # Generate calibrated osm
  model = OpenStudio::Model::Model.load(osm_path).get
  parameters = CSV.read(priors_path, headers: true)
  parameter_names = parameters['Object in the model']
  parameter_types = parameters['Parameter Type']

  posterior = CSV.read(posts_path, headers: true, converters: :numeric)
  headers = posterior.headers()
  posterior_average = [0] * headers.length
  headers.each_with_index do |header, index|
    posterior_average[index] = average(posterior[header])
  end

  uncertainty_parameters = UncertainParameters.new
  parameter_value = posterior_average
  uncertainty_parameters.apply(
    model, parameter_types, parameter_names, parameter_value
  )
  workbook = RubyXL::Parser.parse(outfile_path)
  meters_table = []
  meters_table_row = []
  workbook['Meters'].each do |row|
    meters_table_row = []
    row.cells.each { |cell| meters_table_row.push(cell.value) }
    meters_table.push(meters_table_row)
  end

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

  model.save("#{cal_model_folder}/#{cal_model_name}.osm", true)

  runner = RunOSM.new
  runner.run_osm(cal_model_folder, epw_path, "#{cal_model_folder}/Simulations")

  # Read Simulation Results
  sql_file_path =
    "#{cal_model_folder}/Simulations/#{cal_model_name}/run/eplusout.sql"
  output_folder = cal_model_folder
  OutPut.read([sql_file_path], outfile_path, output_folder)
end

puts 'BC.rb Completed Successfully!'
