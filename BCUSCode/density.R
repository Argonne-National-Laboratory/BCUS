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
# - Created on Feb 27, 2015 by Matt Riddle from Argonne National Laboratory

# 1. Introduction
# This is the function to evaluate a density function for a specified type of
# distribution

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'





#===============================================================%
#     author: Matt Riddle                                       %
#     date: Feb 27, 2015										                    %
#===============================================================%

# density2: Function to evaluate a density function for a specified
#               type of distribution
#

#         Use this function to:
#            1. Evaluate a density function for a specified
#               type of distribution at a specified value

# CALLED BY: logpost.R, graphPosteriors.R

#

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
