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

# 1. Introduction
# This is the main code used for running Bayesian calibration to generate
# posterior distributions and graphing results

require 'optparse'

require_relative 'main'

# Parse command line inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: BC.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('-o', '--osm OSMNAME', 'osmName') do |osm_name|
    options[:osmName] = osm_name
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('-e', '--epw EPWNAME', 'epwName') do |epw_name|
    options[:epwName] = epw_name
  end

  options[:priorsFile] = 'Parameter_Priors.csv'
  opts.on(
    '--priorsFile PRIORSFILE',
    'Prior uncertainty information file, default "Parameter_Priors.csv"'
  ) do |priors_file|
    options[:priorsFile] = priors_file
  end

  options[:utilityData] = 'Utility_Data.csv'
  opts.on(
    '--utilityData UTILITYDATA',
    'Utility data file, default "Utility_Data.csv"'
  ) do |utility_data|
    options[:utilityData] = utility_data
  end

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on(
    '--outFile OUTFILE',
    'Simulation output setting file, default "Simulation_Output_Settings.xlsx"'
  ) do |out_file|
    options[:outFile] = out_file
  end

  options[:simFile] = 'cal_sim_data.txt'
  opts.on(
    '--simFile SIMFILE',
    'Filename of simulation outputs, default "cal_sim_data.txt"'
  ) do |sim_file|
    options[:simFile] = sim_file
  end

  options[:fieldFile] = 'cal_field_data.txt'
  opts.on(
    '--fieldFile FIELDFILE',
    'Filename of utility data for comparison, default "cal_field_data.txt"'
  ) do |field_file|
    options[:fieldFile] = field_file
  end

  options[:postsFile] = 'Parameter_Posteriors.csv'
  opts.on(
    '--postsFile POSTSFILE',
    'Filename of posterior distributions, default "Parameter_Posteriors.csv"'
  ) do |posts_file|
    options[:postsFile] = posts_file
  end

  options[:pvalsFile] = 'pvals.csv'
  opts.on(
    '--pvalsFile PVALSFILE',
    'Filename of pvals, default "pvals.csv"'
  ) do |pvals_file|
    options[:pvalsFile] = pvals_file
  end

  options[:numLHD] = 500
  opts.on(
    '--numLHD NUMLHD',
    'Number of sample points of Monte Carlo simulation ' \
    'with Latin Hypercube Design sampling, default 500'
  ) do |num_lhd|
    options[:numLHD] = num_lhd
  end

  options[:numMCMC] = 30_000
  opts.on(
    '--numMCMC NUMMCMC', 'Number of MCMC steps, default 3000'
  ) do |num_mcmc|
    options[:numMCMC] = num_mcmc
  end

  options[:numBurnin] = 500
  opts.on(
    '--numBurnin NUMBURNIN',
    'Number of burning samples to throw out, default 500'
  ) do |num_burnin|
    options[:numBurnin] = num_burnin
  end

  options[:numOutVars] = 1
  opts.on(
    '--numOutVars NUMOUTVARS',
    'Number of output variables, 1 or 2, default 1'
  ) do |num_out_vars|
    options[:numOutVars] = num_out_vars
  end
  options[:numWVars] = 2
  opts.on(
    '--numWVars NUMWVARS', 'Number of weather variables, default 2'
  ) do |num_w_vars|
    options[:numWVars] = num_w_vars
  end

  options[:randSeed] = 0
  opts.on(
    '--seed SEEDNUM',
    'Integer random number seed, 0 = no seed, default 0'
  ) do |seednum|
    options[:randSeed] = seednum
  end

  options[:numProcesses] = 0
  opts.on(
    '--numProcesses NUMPROCESSES',
    'Number of parallel processes for simulation, 0 = no parallel, default 0'
  ) do |n_processes|
    options[:numProcesses] = n_processes
  end

  options[:noSim] = false
  opts.on('--noSim', 'Do not run computer simulation') do
    options[:noSim] = true
  end

  options[:noEP] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noEP] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files.') do
    options[:noCleanup] = true
  end

  options[:noPlots] = false
  opts.on('--noPlots', 'Do not produce any PDF plots') do
    options[:noPlots] = true
  end

  options[:noRunCal] = false
  opts.on('--noRunCal', 'Do not run the calibrated model when complete') do
    options[:noRunCal] = true
  end

  options[:interactive] = false
  opts.on(
    '-i', '--interactive',
    'Run with interactive prompts to check setup files.'
  ) do
    options[:interactive] = true
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

# Run main analysis function
Main.run('BC', options)

puts 'BC.rb Completed Successfully!'
