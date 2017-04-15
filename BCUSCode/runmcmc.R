#                    Copyright © 2016 , UChicago Argonne, LLC
#                              All Rights Reserved
#                               OPEN SOURCE LICENSE

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.  Software changes, modifications, or 
# derivative works, should be noted with comments and the author and organization’s name.

# 2. Redistributions in binary form must reproduce the above copyright notice, this list
# of conditions and the following disclaimer in the documentation and/or other materials 
# provided with the distribution.

# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names
# of its contributors may be used to endorse or promote products derived from this software 
# without specific prior written permission.

# 4. The software and the end-user documentation included with the redistribution, if any, 
# must include the following acknowledgment:

# "This product includes software produced by UChicago Argonne, LLC under Contract 
# No. DE-AC02-06CH11357 with the Department of Energy.”

# ******************************************************************************************************
#                                             DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, 
# LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY 
# OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, 
# PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

# ***************************************************************************************************

# Modified Date and By:
# - Created on Feb 27, 2015 by Matt Riddle from Argonne National Laboratory

# 1. Introduction
# This is the function to 
#               1. Call function to read parameter info
#               2. Call function to setup params structure
#               3. Call MCMC algorithm

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'


#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%
#
# runmcmc: Driver function for using GASP model to combine
#            field data and computer simulations for calibration
#            and prediction.
#
#            Use this function to:
#               1. Call function to read parameter info
#               2. Call function to setup params structure
#               3. Call MCMC algorithm

# CALLS: readFromParamFile.R, setupParams.R, gaspmcmc.R

#==============================================================#
#                        REQUIRED INPUTS                       #
#==============================================================#
# params_filename: name for file with info on parameter prior distributions
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
# com_filename: name for file with results of computer model runs
#   first columns (# columns specified in numYVars): model output 
#   next columns (# columns specified in numXVars): 
#     values for x (e.g., weather) variables used in model runs
#   remaining columns (# columns should match number of rows in params_filename): 
#     values for theta parameters used in model runs
#
# field_filename: name for file with observed data used for calibration
#   first columns (# columns specified in numYVars): observed output
#   next columns: observed x (e.g., weather) data
#
# numYVars = number of y (output) variables in input files
#
# numXVars = number of x (e.g., weather) variables in input files
# 
# numMCMCSteps: the number of steps to run the mcmc algorithm for
#   suggested number: 5000 **we will test more to refine number of steps needed**
# 
# pvals_filename: filename that diagnositc results of mcmc runs will be saved to
# 
# posteriorDist_filename: filename that posterior distributions for parameters
#   will be saved to
#
# COMMENTS: This program does all the necessary standardization...
#           Simply input raw values.

#===============================================================#
#                           OUTPUTS                             #
#===============================================================#
# Instead of returning outputs, the function saves the results
#   to files:
# posteriorDists: posterior realizations (nmcmc x nparms)
#        Each row is a realization from the posterior distribution 
#        and each column corresponds to a parameter
# pvals: posterior realizations for parameters and hyperparameters
#        Each row is a realization from the posterior distribution 
#        and each column corresponds to a parameter, hyperparameter
#        or the log-likelihoods and log-posterior values 
#        parameter posteriors are transformed onto 0-1 scale
#        order of parameters and hyperparameters: theta(q), 
#        beta_eta(p+q), beta_b(q), lambda_eta, lambda_en, lambda_b, 
#        lambda_e
#        then columns for log-posterior and log-likelihood

# COMMENTS: 
#           See model description below for more information on
#           parameters.

#===============================================================#
#                          MODEL DETAILS                        #
#===============================================================#
# n field experiments at design points xf
# Field response:  yf = eta(xf,theta) + b(xf) + e

# eta(xf,theta): computer model at field design points and 
#                true value of calibration parameters, theta
#         b(xf): bias/discrepancy function
#             e: observation error
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# m computer simulations at designs points (xc,tc)
# Computer response: yc = eta(xc,tc) + en


# eta(xc,tc): computer model at computer design points
#             and computer input calibration design points
#         en: small random error on computer code
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# eta ~ N(0,sigma_eta) hypers: theta, beta_eta, lambda_eta
#  b  ~ N(0,sigma_b)   hypers: beta_b, lambda_b
#  e  ~ N(0,sigma_e)   hypers: lambda_e
# en  ~ N(0,sigma_en)  hypers: lambda_en 

# Full data: y = [yf', yc']': n+m x 1
# Standardize response y by mean and standard deviation of yc

# y|. ~ N(0,sigma_y)
# sigma_y = sigma_eta + |sigma_b    0| + |sigma_e      0    |
#                       |    0      0|   |   0     sigma_en |

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# sigma_eta = 1/lambda_eta C(z,z') --> (n+m) x (n+m)
# C(z,z') = exp{-sum_{k=1:p+q}beta_eta(k)(z(k)-z'(k))^2}
# z = [(xf,theta);(xc,tc)]

# sigma_b = 1/lambda_b C(xf,xf') --> (n x n)
# C(xf,xf') = exp{-sum_{k=1:p}beta_b(k)(xf(k)-xf'(k))^2}

# sigma_e = 1/lambda_e I[n]

# sigma_en = 1/lambda_en I[m]

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MCMC algorithm is used to obtain realizations from posterior 
# distribution:
# theta,beta_eta,beta_b,lambda_eta,lambda_en,lambda_b,lambda_e|y

#===============================================================#

runmcmc <- function(params_filename, com_filename, field_filename, numYVars, numXVars, numMCMCSteps, pvals_filename, posterior_dists_filename, verbose = 0, randseed = 0){
  
  

  #for testing, can use values below for parameters that are passed in
  
#  params_filename = "../../Input/Calibration_Parameters_Prior.csv"
#  com_filename = "../../Input/cal_sim_runs.txt"
#  field_filename = "../../Input/cal_utility_data.txt"
#  numXVars = 2
#  numYVars = 2
#  numMCMCSteps = 10
#  pvals_filename = "../../Output/pvals2.csv"
#  posterior_dists_filename = "../../Output/posteriorDists2.csv"

  source("gendist.R")
  source("gaspmcmc.R")
  source("logpost.R")
  source("genODUTInds.R")
  source("genRectInds.R")
  source("gaspcovTri.R")
  source("gaspchcov.R")
  source("gaspcov.R")
  source("gaspcovFromTri.R")
  source("density.R")
  source("setupParams.R")
  source("readFromParamFile.R")

    theta_info <- readFromParamFile(params_filename)

  params <- setupParams(theta_info, com_filename, field_filename, numYVars, numXVars, numMCMCSteps, verbose)  
  pvals <- gaspmcmc(params, verbose, randseed)
  posterior_dists <- matrix(nrow = nrow(pvals), ncol = length(theta_info))
  for (i in 1:length(theta_info)){
    tmin <- theta_info[[i]]$min
    tmax <- theta_info[[i]]$max
    posterior_dists[,i] <- pvals[,i]*(tmax - tmin) + tmin
  }
  if (verbose == 1){
    message(sprintf("Writing %s",pvals_filename))
	message(sprintf("writing %s", posterior_dists_filename)) 
  }

  write.csv(pvals, pvals_filename, row.names = FALSE)
  write.csv(posterior_dists, posterior_dists_filename, row.names = FALSE)
  
}
