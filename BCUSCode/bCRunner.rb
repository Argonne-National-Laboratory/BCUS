# Copyright © 2016 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.  Software changes,
#    modifications, or derivative works, should be noted with comments and the
#    author and organization's name.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor
#    the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# 4. The software and the end-user documentation included with the
#    redistribution, if any, must include the following acknowledgment:
#
#    "This product includes software produced by UChicago Argonne, LLC under
#     Contract No. DE-AC02-06CH11357 with the Department of Energy."
#
# *****************************************************************************
# DISCLAIMER
#
# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.
#
# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
#
# *****************************************************************************

# Modified Date and By:
# - Created on February 2015 by Matt Riddle from Argonne National Laboratory

# 1. Introduction
# This is the function to call Bayesian Calibration code in R

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'

#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%

# runBC: Function to call Bayesian Calibration code in R
#

#         Use this function to:
#      1. Convert Ruby parameters into R parameters
#			 2. Call Bayesian Calibration code in R

# CALLED BY: bCRunner.rb
# CALLS: runmcmc.R

#==============================================================#
#                        REQUIRED INPUTS                       #
#==============================================================#
# params_filename: name for file with info on parameter prior distributions
# com_filename: name for file with info results of computer model runs
# field_filename: name for file info on observed data used for calibration
# numOutputVars = number of y (output) variables in input files
# numWeatherVars = number of x (e.g., weather) variables in input files
# numMCMCSteps: the number of steps to run the mcmc algorithm for
# pvals_filename: filename that diagnositc results of mcmc runs will be saved to
# posteriorDist_filename: filename that posterior distributions for parameters
#   will be saved to

#===============================================================#
#                           OUTPUTS                             #
#===============================================================#
# None, but runmcmc.R will generate output files
#
# posteriorDists: posterior realizations (nmcmc x nparms)
# pvals: posterior realizations for parameters and hyperparameters
#===============================================================%

require_relative 'rinruby'
#         Use this function to:
#      1. Convert Ruby parameters into R parameters
#      2. Call Bayesian Calibration code in R
module BCRunner
  def BCRunner.runBC(code_path, priors_filename, com_filename, field_filename,
                     numOutputVars, numWeatherVars, numMCMCSteps,
                     pvals_filename, posterior_dists_filename,
                     verbose = false, randseed = 0)

    # R in ruby doesn't allow one to assign boolean values, so we need to
    # kludge the passing by using integers, 1 = true, 0 = false
    if verbose
      R.assign('verbose', 1)
    else
      R.assign('verbose', 0)
    end
    R.assign('work_dir', code_path)
    R.eval('setwd(work_dir)')
    R.eval("source('runmcmc.R')")
    R.assign('randseed', randseed)

    R.assign('params_filename', priors_filename)
    R.assign('com_filename', com_filename)
    R.assign('field_filename', field_filename)
    R.assign('numOutputVars', numOutputVars)
    R.assign('numWeatherVars', numWeatherVars)
    R.assign('numMCMCSteps', numMCMCSteps)
    R.assign('pvals_filename', pvals_filename)
    R.assign('posterior_dists_filename', posterior_dists_filename)

    R.eval('runmcmc(params_filename, com_filename, field_filename,
      numOutputVars, numWeatherVars, numMCMCSteps, pvals_filename,
      posterior_dists_filename, verbose, randseed)')
  end
end
