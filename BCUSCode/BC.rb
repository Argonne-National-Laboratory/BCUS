# Copyright © 2019, UChicago Argonne, LLC
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

# CALLS: BC_runner.rb, graph_generator.rb

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
require_relative 'uncertain_parameters'
require_relative 'BC_runner'
require_relative 'run_osm'
require_relative 'process_simulation_sqls'
require_relative 'graph_generator'
require_relative 'calibrated_osm'
require_relative 'bcus_utils'

# Parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: Bayesian_Calibration.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('-o', '--osmName',  'osmName') do |osm_name|
    options[:osmName] = osm_name
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('-e', '--epwName', 'epwName') do |epw_name|
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

  options[:priorsFile] = 'Parameter_Priors.csv'
  opts.on(
    '--priors priorsFile',
    'Prior uncertainty information file, default "Parameter_Priors.csv"'
  ) do |priors_file|
    options[:priorsFile] = priors_file
  end

  options[:postsFile] = 'Parameter_Posteriors.csv'
  opts.on(
    '--postsFile postsFile',
    'Filename of posterior distributions (default = "Parameter_Posteriors.csv")'
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

  options[:noEP] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noeEP] = true
  end

  options[:noplots] = false
  opts.on('--noPlots', 'Do not produce any PDF plots') do
    options[:noplots] = true
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
error_msg = 'An OpenStudio OSM file must be indicated by the --osm option ' \
  'or giving a filename ending with .osm on the command line'
osm_path = File.absolute_path(parse_argv(options[:osmName], '.osm', error_msg))

# If the user didn't give the --epwName option, parse the rest of the input
# arguments for a *.epw
error_msg = 'An .epw weather file must be indicated by the --epw option ' \
  'or giving a filename ending with .epw on the command line'
epw_path = File.absolute_path(parse_argv(options[:epwName], '.epw', error_msg))


# Assign analysis settings
priors_path = File.absolute_path(options[:priorsFile])
outspec_path = File.absolute_path(options[:outFile])

com_name = options[:comFile]
field_name = options[:fieldFile]
posts_name = options[:postsFile]
pvals_name = options[:pvalsFile]

num_mcmc = Integer(options[:numMCMC])
num_out_vars = Integer(options[:numOutVars])
num_w_vars = Integer(options[:numWVars])
num_burnin = Integer(options[:numBurnin])
randseed = Integer(options[:randseed])
no_run_cal = options[:noRunCal]
skip_cleanup = options[:noCleanup]
no_plots = options[:noplots]
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
building_name = File.basename(osm_path, '.osm')

# Check if .osm model exists and if so, load it
model = read_osm_file(osm_path, verbose)

# Check if or .epw file exists and if so, load it 
check_epw_file(epw_path, verbose)

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
prerun_dir = File.join(path, 'PreRuns_Output')
output_dir = File.join(path, 'Calibration_Output')
com_path = File.join(prerun_dir, com_name)
field_path = File.join(prerun_dir, field_name)
posts_path = File.join(output_dir, posts_name)
pvals_path = File.join(output_dir, pvals_name)
graphs_dir = output_dir
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

check_file_exist(priors_path, 'Priors CSV File', verbose)
check_file_exist(com_path, 'Computer Simulation File', verbose)
check_file_exist(field_path, 'Utility Data File', verbose)

# Perform Bayesian calibration
code_path = ENV['BCUSCODE']
puts "Using code path = #{code_path}\n\r" if verbose
BCRunner.run_BC(
  code_path, priors_path, com_path, field_path,
  num_out_vars, num_w_vars, num_mcmc,
  pvals_path, posts_path, randseed, verbose
)

if num_burnin >= num_mcmc
  puts 'Warning: numBurnin should be less than numMCMC. ' \
       "numBurnin has been reset to 0.\n"
  num_burnin = 0
end

puts 'Generating posterior distribution plots' if verbose
# Could pass in graph file names too
unless no_plots
  GraphGenerator.graphPosteriors(
    priors_path, pvals_path, num_burnin, graphs_dir, verbose
  )
end

# Run calibrated model
unless no_run_cal
  puts "\nGenerate and run calibrated model" if verbose

  cal_model_dir = File.join(path, 'Calibrated_Model')
  cal_model_path = File.join(cal_model_dir, "Calibrated_#{building_name}.osm")

  cal_osm = CalibratedOSM.new
  cal_osm.gen_and_sim(
    osm_path, epw_path, priors_path, posts_path,
    outspec_path, cal_model_path, cal_model_dir, verbose
  )

end

puts 'BC.rb Completed Successfully!'
