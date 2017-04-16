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
- August 2016 by Yuna Zhang
- Created on Feb 15 2015 by Yuming Sun from Argonne National Laboratory
- 08-Apr-2017 Ralph Muehleisen added -n and --noEP option for consistency with others but they don't do anything  
                               This allows you to pass the same options to bc_setup and bc

1. Introduction
This is the main code used for running Bayesian calibration to generate posterior distributions and graphing results

2. Call structure
Refer to 'Function Call Structure_Bayesian Calibration.pptx'
=end

#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for running Bayesian calibration to generate 
# 		posterior distributions and graphing results
#

# CALLS: bCRunner.rb, graphGenerator.rb

#==============================================================#
#                        REQUIRED INPUTS 			           #
#==============================================================#
# the following input files must have been created in the input
#   folder for the project before running this:
#
# Calibration_Parameters_Prior.csv: file with info on parameter 
#		prior distributions
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
#   remaining columns (# columns should match number of rows in params_filename): 
#     values for theta parameters used in model runs
#
# cal_data_field.txt: file with observed data used for calibration
#   first columns (# columns specified in numYVars): observed output
#   next columns: observed x (e.g., weather) data
#
#==============================================================#
# in addition, the following options should be specified when 
#	this is called from Ruby:
# projectName: name of project
#	used to name folders for storing inputs and outputs
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
# 	posterior_dists.csv: posterior realizations (nmcmc x num parameters)
#   PosteriorVsPrior1.pdf ... posteriorVsPriorN.pdf (N = numTheta)
#		a set of histograms, one per parameter, showing posterior
#       distributions for the parameter compared against its prior 
#       distribution
#   posteriorScatterPlotsV1.pdf and posteriorScatterPlotsV2.pdf
#		two versions of a matrix of graphs with the diagonal 
#		matrices showing posterior distributions for each 
#		parameter and the off-diagonal showing scatter plots 
#		of the joint distributions for each pair of parameters
#		These will be generated only if 2 <= numTheta <= 6 
#   
#===============================================================%
# $LOAD_PATH.unshift('/Applications/OpenStudio 1.5.0/Ruby')
# $: << File.join(File.dirname(__FILE__))

# load in the required ruby libraries
require 'openstudio'
require 'optparse'
require 'csv'
require 'fileutils'

# load in our own libraries
require_relative 'graphGenerator'
require_relative 'calibrateOSModel'
require_relative 'bCRunner'

# parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: Bayesian_Calibration.rb [options]'

  opts.on('--osmName osmName', 'Name of .osm file to run') do |osmName|
    options[:osmName] = osmName
  end

  opts.on('--epwName epwName', 'Name of .epw weather file to use') do |epwName|
    options[:epwName] = epwName
  end

  options[:comFile]='cal_sim_runs.txt'
  opts.on('--comFile comFile', 'Filename of simulation outputs (default = "cal_sim_runs.txt")') do |comFile|
    options[:comFile] = comFile
  end

  options[:fieldFile]='cal_utility_data.txt'
  opts.on('--fieldFile fieldFile', 'Filename of utility data for comparison (default = "cal_utility_data.txt")') do |fieldFile|
    options[:fieldFile] = fieldFile
  end

  options[:numMCMC] = 30000
  opts.on('--numMCMC numMCMC', 'Number of MCMC steps (default = 30000)') do |numMCMC|
    options[:numMCMC] = numMCMC
  end

  options[:numOutVars] = 1
  opts.on('--numOutVars numOutVars', 'Number of output variables, 1 or 2 (default=1)') do |numOutVars|
    options[:numOutVars] = numOutVars
  end
  options[:numWVars] = 2
  opts.on('--numWVars numWVars', 'Number of weather variables (default = 2)') do |numWVars|
    options[:numWVars] = numWVars
  end

  options[:numBurnin] = 500
  opts.on('--numBurnin numBurnin', 'Number of burning samples to throw out (default = 500)') do |numBurnin|
    options[:numBurnin] = numBurnin
  end

  options[:priorsFile]='priors.csv'
  opts.on('--priorsFile priorsFile', 'Filename of priors distributions (default = "priors.csv")') do |priorsFile|
    options[:priorsFile] = priorsFile
  end

  options[:postsFile]='posteriors.csv'
  opts.on('--postsFile postsFile', 'Filename of posterior distributions (default = "posteriors.csv")') do |postsFile|
    options[:postsFile] = postsFile
  end

  options[:pvalsFile]='pvals.csv'
  opts.on('--pvalsFile pvalsFile', 'Filename of pvals (default = "pvals.csv")') do |pvalsFile|
    options[:pvalsFile] = pvalsFile
  end


  options[:randseed] = 0
  opts.on('--seed seednum', 'Integer random number seed, 0 = no seed, default = 0') do |seednum|
    options[:randseed] = seednum
  end

  options[:noRunCal] = false
  opts.on('--noRunCal', 'Do not run the calibrated model when complete') do
    options[:noRunCal] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end
  
  options[:noEP] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noeEP] = true
  end
  
  options[:verbose] = false
  opts.on('-v', '--verbose', 'Run in verbose mode with more output info printed') do
    options[:verbose] = true
  end
  
  options[:noplots] = false
  opts.on('--noPlots','Do not produce any PDF plots') do 
    options[:noplots] = true
  end
  
 options[:settingsFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-s', '--settingsfile outFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |settingsFile|
    options[:settingsFile] = settingsFile
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

building_model=File.basename(osm_name)
building_name=File.basename(osm_name, '.osm')
osm_path = File.absolute_path(osm_name)


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

epw_file = File.absolute_path(epw_name)

# require the following files from parametric simulations
# Calibration_Parameters_Prior.csv
# cal_data_field.txt
# cal_data_com.txt

# LHS design is used now
# Space filling design could be adopted later

# Cal_data_com.txt: Computation data
# In the order of: Monthly Energy Output;
#                  Monthly Dry-bulb Temperature (C),
#                  Monthly Global Horizontal Solar Radiation (W/M2)
#                  Calibration Parameters

# Cal_data_field.txt: Observed data
# In the order of: Monthly Energy Output;
#                  Monthly Dry-bulb Temperature (C),
#                  Monthly Global Horizontal Solar Radiation (W/M2)

#input file names

path = Dir.pwd
output_folder = "#{path}/Calibration_Output"

priors_file = File.absolute_path(options[:priorsFile])

cal_data_com_path = File.absolute_path(options[:comFile])
cal_data_field_path = File.absolute_path(options[:fieldFile])
posts_name = options[:postsFile]
pvals_name = options[:pvalsFile]
settings_file = File.absolute_path(options[:settingsFile])

numMCMC = Integer(options[:numMCMC])
numOutVars = Integer(options[:numOutVars])
numWVars = Integer(options[:numWVars])
numBurnin = Integer(options[:numBurnin])
randseed = Integer(options[:randseed])
verbose = options[:verbose]
no_run_cal= options[:noRunCal]
noEP = options[:noEP]
noplots = options[:noplots]


skip_cleanup = options[:noCleanup]

code_path = ENV['BCUSCODE']

if verbose
  puts 'Not Cleaning Up Interim Files' if skip_cleanup
  puts "Using output_folder = #{output_folder}"
  puts "Using numOutVars = #{numOutVars}"
  puts "Using numWVars = #{numWVars}"
  puts "Using numMCMC = #{numMCMC}"
  puts "Using numBurnin = #{numBurnin}"
  puts "Using Random Number Seed = #{randseed}"
  puts "Writing to Posterior Values File = #{posts_name}"
  puts "Writing to Pvals File = #{pvals_name}"
  puts "Using Code path = #{code_path}"
  puts
end

#output file names

# check for existence of input files

# check if priors file exists
if File.exist?("#{priors_file}")
  puts "Using Priors CSV file #{priors_file}" if verbose
else
  puts "Priors file #{priors_file} not found!"
  abort
end

# check if COM file exists
if File.exist?("#{cal_data_com_path}")
  puts "Using Simulation Output file= #{cal_data_com_path}" if verbose
else
  puts "com.txt file #{cal_data_com_path} not found!"
  abort
end

# check if FIELD file exists
if File.exist?("#{cal_data_field_path}")
  puts "Using Utility Data file= #{cal_data_field_path}" if verbose
else
  puts "field.txt file #{cal_data_field_path} not found!"
  abort
end

Dir.mkdir "#{output_folder}" unless Dir.exist?("#{output_folder}")

posts_file = "#{output_folder}/#{posts_name}"
pvals_file = "#{output_folder}/#{pvals_name}"

BCRunner.runBC(code_path, priors_file, cal_data_com_path, cal_data_field_path,
               numOutVars, numWVars, numMCMC, pvals_file, posts_file, verbose, randseed)


if numBurnin >= numMCMC
  print "warning: numBurnin should be less than numMCMC. numBurnin has been reset to 0.\n"
  numBurnin = 0
end

#could pass in graph file names too
unless noplots
  GraphGenerator.graphPosteriors(priors_file, pvals_file, numBurnin, output_folder, verbose)
end
calibrated_model = Calibrated_OSM.new

meter_set_file = "#{path}/Simulation_Output_Settings.xlsx"
calibrated_output_folder = "#{path}/Calibrated_Model"
calibrated_model_file = "#{output_folder}/Calibrated_#{building_model}"
calibrated_osm_model_name = "Calibrated_#{building_name}"

unless no_run_cal
  puts 'Generate and Run the Calibrated Model' if verbose
  calibrated_model.gen_and_sim(osm_path,epw_file, priors_file, posts_file, settings_file, 
                               calibrated_model_file, calibrated_osm_model_name, output_folder, verbose)

end

puts 'BC.rb Completed Successfully!' if verbose


