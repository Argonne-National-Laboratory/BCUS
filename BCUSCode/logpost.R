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
# - Created on Feb 27, 2015 by Matt Riddle from Argonne National Laboratory

# 1. Introduction
# This is the function to 
#           1. Evaluate likelihood of y|parameters
#           2. SPECIFY bounds on parameters
#           3. SPECIFY prior distributions of parameters
#           4. Calculate log posterior distribution

# 2. Call structure
# Refer to 'Function Call Structure.pptx'


#===============================================================%
#     author: Matt Riddle                                       %
#     date: Feb 27, 2015										                    %
#===============================================================%

# LOGPOST Function to return value of log posterior distribution
#         at a given set of parameter values

#         Use this function to:
#           1. Evaluate likelihood of y|parameters
#           2. SPECIFY bounds on parameters
#           3. SPECIFY prior distributions of parameters
#           4. Calculate log posterior distribution

# CALLED BY: gaspmcmc.R
# calls: density.R

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# sigmayCh: cholesky factorization of covariance matrix sigma_y
# adjparams structure containing information on:
#   theta: true calibration parameter value
#   beta_eta, lambda_eta: parameters for eta 
#   beta_b, lambda_b: parameters for bias
#   lambda_e: precision parameter for observation error
#   lambda_en: precision parameter for random error
# params structure containing information on:
#   y: full data vector
#   theta_info: information on prior distribution function for theta

#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# lpost: value of log posterior density and log-likelihood
# at given parameter values

#===============================================================%
#                          MODEL DETAILS                        %
#===============================================================%
  
# Likelihood: y|. ~ N(0,sigma_y)

# Priors: [theta], [beta_eta], [lambda_eta],
#         [beta_b], [lambda_b], [lambda_e], [lambda_en]

# Posterior: [y|.][theta][beta_eta][lambda_eta]...

# logposterior ~ loglikelihood + logprior

#===============================================================%

loglikelihood = function(sigmayCh, y) {
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Compute log likelihood
  # loglik = -.5*log(det(sigma_y)) - .5*y'{(sigma_y)^(-1)}y
  u <- backsolve(sigmayCh, as.matrix(y), transpose = TRUE)
  # sigmayChInv <- backsolve(sigmayCh, diag(1,ncol(sigmayCh)), transpose = TRUE)
  # u <- sigmayChInv %*% as.matrix(y)
  # u = (sigmayCh)'\y
  Q = t(u)%*%u
  logdet = sum(log(diag(sigmayCh)))
  loglik = -logdet - .5*Q

  lpost <- c(loglik, loglik)
  return(lpost)
}

logprior = function(hyperparams) {
  lambda_eta = hyperparams$lambda_eta
  lambda_en = hyperparams$lambda_en
  beta_eta = hyperparams$beta_eta
  beta_b = hyperparams$beta_b
  lambda_e = hyperparams$lambda_e
  lambda_b = hyperparams$lambda_b

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX%
  # SPECIFY BOUNDS ON PARAMETERS HERE!!! %
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX%

  # OPTION: check for invalid conditions
  # Make log posterior density very unlikely if conditions not met
  if ((lambda_eta < .3) || (lambda_en > 2e5) || (lambda_en < 100.0)) {
    lpost = -9e99
  } else {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX#
    # SPECIFY PRIOR DISTRIBUTIONS HERE!!!#
    #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX#
    # Prior for beta_eta
    # rho_eta = exp(-beta_eta/4)
    # EXAMPLE: rho_eta(k) ~ BETA(1,.5)
    rho_eta = exp(-beta_eta/4)
    rho_eta[which(rho_eta>0.999)] = 0.999
    logprior = - .5*sum(log(1-rho_eta))
    #logprior = (alpha-1)log(rho_eta)+(beta-1)log(1-rho_eta)
    # Prior for beta_b
    # rho_b = exp(-beta_b/4)
    # EXAMPLE: rho_b(k) ~ BETA(1,.4) 
    rho_b = exp(-beta_b/4)
    rho_b[which(rho_b>0.999)] = 0.999
    # logprior = logprior - .6*sum(log(1-rho_b))
    logprior = logprior - .9*sum(log(rho_b)) #BETA(0.4,1)

    # Prior for lambda_eta
    # EXAMPLE: lambda_eta ~ GAM(10,10)
    logprior = logprior + (10-1)*log(lambda_eta) - 10*lambda_eta

    # Prior for lambda_en
    # EXAMPLE: lambda_en ~ GAM(10,.001)
    logprior = logprior + (10-1)*log(lambda_en) - .001*lambda_en

    # Prior for lambda_b
    # EXAMPLE: lambda_b ~ GAM(10,.3)
    logprior = logprior + (10-1)*log(lambda_b) - .00000001*lambda_b

    # Prior for lambda_e
    # EXAMPLE: lambda_e ~ GAM(10,.03)
    logprior = logprior + (10-1)*log(lambda_e) - .03*lambda_e

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Compute log posterior
    lpost <- c(logprior, 0)
  }
  return(lpost)
}

logpriortheta = function(theta, theta_info) {

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX%
  # SPECIFY BOUNDS ON PARAMETERS HERE!!! %
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX%


  # Prior for theta
  num_theta = length(theta_info)
  logprior = 0
  for (ti in 1:num_theta) {
    logprior = logprior + log(density2(theta_info[[ti]]$prior, theta[1, ti]))
  }

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Compute log posterior
  lpost <- c(logprior, 0)
  return(lpost)
}


# density2: Function to evaluate a density function for a specified
#               type of distribution at a specified value

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
#   distribution: a structure that contains
#     type: a string with the type of distribution
#       current options are: 'triangular', 'uniform', 'normal'
#     additional fields that depend on the distribution type: 
#   val: the value at which to apply the density function
#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# density: the value of the density function

#===============================================================%

density2 <- function(distribution, val) {

  if (distribution$type == 'triangular') {
    min = distribution$min
    max = distribution$max
    mode = distribution$mode
    if ((val>=min) && (val<=mode)) {
      density = 2 * (val-min) / ((max-min)*(mode-min))
    } else if ((val > mode) && (val <= max)) {
      density = 2 * (max-val) / ((max-min)*(max-mode))
    } else {
	  density = 0
	  }
  } else if (distribution$type == 'normal') {
    mean = distribution$mean
    stDev = distribution$stDev
    density = (exp(-(((val-mean)/stDev)^2)/2)) / (stDev*sqrt(2*pi))
  } else if (distribution$type == 'uniform') {
    min = distribution$min
    max = distribution$max
    if ((val >= min) && (val <= max)) {
	  density = 1 / (max-min)
    } else {
      density = 0
    }
  } else if (distribution$type == 'lognormal') {
    # print(sprintf('lognormal distribution not supported yet'))
    # density = 0
    mu = distribution$mu
    sig = distribution$sig
    # density = (exp((x-mean)/stdev)^2)/(2*pi)
    density = (exp(-(((log(val)-mu)/sig)^2)/2)) / (val*sig*sqrt(2*pi))
  } else {
    print(sprintf('unsupported distribution type: %s', distribution$type))
    density = 0
  }

  return(density)
}


logDensityKernelNotWorkingYet <- function(distribution, val) {

# this evaluates the density for a given distribution
# at the specified value
#
#   distribution is a structure that contains
#     type: a string with the type of distribution
#       current options are: 'triangular'
#     params: a list of parameters associated with
#       that type of distribution
#       for triangular distribution, the first 
#       param is the minimum, second is maximum, 
#       and third is the value where the density
#       function peaks

  if (distribution$type == 'triangular') {
    min = distribution$min
    max = distribution$max
    mode = distribution$mode
    if ((val>=min) && (val<=mode)) {
      density = 2 * (val-min) / ((max-min)*(mode-min))
    } else {
      density = 2 * (max-val) / ((max-min)*(max-mode))
    }
  } else if (distribution$type == 'normal') {
    mean = distribution$mean
    stDev = distribution$stDev
    density = (exp((x-mean)/stDev)^2) / (2*pi)
  } else if (distribution$type == 'uniform') {
    min = distribution$min
    max = distribution$max
      if ((val>=min) && (val<=max)) {
      density = 1 / (max-min)
      }
  } else if (distribution$type == 'lognormal') {
    print(sprintf('lognormal distribution not supported yet'))
    density = 0
	# mean = distribution$mean
	# stdev = distribution$stdev
	# density = (exp((x-mean)/stdev)^2)/(2*pi)
  } else {
    print(sprintf('unsupported distribution type: %s', distribution$type))
    density = 0
  }

  return(density)
}
