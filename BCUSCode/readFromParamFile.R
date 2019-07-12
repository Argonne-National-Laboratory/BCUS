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
# This is the function to read parameter info from file

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'



#===============================================================%
#     author: Matt Riddle                                       %
#     date: Feb 27, 2015										                    %
#===============================================================%
#
# readFromParamFile: Reads parameter info from file
#
#            Use this function to:
#               1. Read parameter info from file

# CALLED BY: runmcmc.R, runPred.R

#==============================================================#
#                        REQUIRED INPUTS                       #
#==============================================================#
# filename: name for file with info on parameter prior distributions
#   first column: Parameter Type
#   second column: Object in the model
#   third column: Parameter Base Value (for relative distributions)
#   fourth column: Distribution
#   fifth column: Mean or Mode
#   sixth column: Std Dev
#   seventh column: Min
#   eigth column: Max
#
#===============================================================#
#                           OUTPUTS                             #
#===============================================================#
# theta_info: a list of structures with info about prior distributions
#     of parameters. Each element has the fields:
#     $name 
#     $min
#     $max
#     $prior
#       $type
#       depending on the type, the subfields of prior can be different:
#          for 'triangular'
#            $min
#            $max
#            $mode
#          for 'uniform'
#            $min
#            $max
#          for 'normal'
#            $mean
#            $stDev
#          for 'lognormal'
#            $mu
#            $sig
#
# COMMENTS: lognormal distriubtions are not supported yet

readFromParamFile <- function(filename) {
	theta_csv <- read.csv(filename, header=TRUE, stringsAsFactors=FALSE, sep=",")
	theta_csv$Min[[2]]
	num_theta = nrow(theta_csv)
	theta_info <- list()
  for (i in 1:num_theta) {
    theta_info[[i]] <- list()
    paramType <- theta_csv$Parameter.Type[[i]]
    objectInModel <- theta_csv$Object.in.the.model[[i]]
    distributionName <- theta_csv$Distribution[[i]]
    baseValue <- theta_csv$Parameter.Base.Value[[i]]
    meanOrMode <- theta_csv$Mean.or.Mode[[i]]
    min <- theta_csv$Min[[i]]
    max <- theta_csv$Max[[i]]
    stDev <- theta_csv$Std.Dev[[i]]

    name <- paste(paramType, objectInModel, sep = ":")
    theta_info[[i]]$name <- name

    theta_info[[i]]$prior <- list()
    if (distributionName == "Triangle Absolute") {
      theta_info[[i]]$prior$type <- "triangular"
      theta_info[[i]]$prior$min <- min
      theta_info[[i]]$prior$max <- max
      theta_info[[i]]$prior$mode <- meanOrMode
      theta_info[[i]]$min <- min
      theta_info[[i]]$max <- max
    }
    else if (distributionName == "Triangle Relative") {
      theta_info[[i]]$prior$type <- "triangular"
      theta_info[[i]]$prior$min <- min * baseValue
      theta_info[[i]]$prior$max <- max * baseValue
      theta_info[[i]]$prior$mode <- meanOrMode * baseValue
      theta_info[[i]]$min <- min * baseValue
      theta_info[[i]]$max <- max * baseValue
    }
    else if (distributionName == "Uniform Absolute") {
      theta_info[[i]]$prior$type <- "uniform"
      theta_info[[i]]$prior$min <- min
      theta_info[[i]]$prior$max <- max
      theta_info[[i]]$min <- min
      theta_info[[i]]$max <- max
    }
    else if (distributionName == "Uniform Relative") {
      theta_info[[i]]$prior$type <- "uniform"
      theta_info[[i]]$prior$min <- min * baseValue
      theta_info[[i]]$prior$max <- max * baseValue
      theta_info[[i]]$min <- min * baseValue
      theta_info[[i]]$max <- max * baseValue
    }
    else if (distributionName == "Normal Absolute") {
      theta_info[[i]]$prior$type <- "normal"
      theta_info[[i]]$prior$mean <- meanOrMode
      theta_info[[i]]$prior$stDev <- stDev
      theta_info[[i]]$min <- min
      theta_info[[i]]$max <- max
      # z99 = 2.33
      # theta_info[[i]]$min <- theta_info[[i]]$prior$mean -
      #   z99 * theta_info[[i]]$prior$stDev
      # theta_info[[i]]$max <- theta_info[[i]]$prior$mean +
      #   z99 * theta_info[[i]]$prior$stDev
    }
    else if (distributionName == "Normal Relative") {
      theta_info[[i]]$prior$type <- "normal"
      theta_info[[i]]$prior$mean <- meanOrMode * baseValue
      theta_info[[i]]$prior$stDev <- stDev * baseValue
      theta_info[[i]]$min <- min * baseValue
      theta_info[[i]]$max <- max * baseValue
      # z99 = 2.33
      # theta_info[[i]]$min <- theta_info[[i]]$prior$mean -
      #   z99 * theta_info[[i]]$prior$stDev
      # theta_info[[i]]$max <- theta_info[[i]]$prior$mean +
      #   z99 * theta_info[[i]]$prior$stDev
    }
    else if (distributionName == "Lognormal Absolute") {
      theta_info[[i]]$prior$type <- "lognormal"
      theta_info[[i]]$prior$mu <- meanOrMode
      theta_info[[i]]$prior$sig <- stDev
      # min must be zero to allow transformation to 0-1 range and
      # still be lognormal
      theta_info[[i]]$min <- 0
      #todo: if max is left blank, use some default (e.g. 99% percentile)
      #theta_info[[i]]$max <- max
      z99 = 2.33
      theta_info[[i]]$max <- exp(theta_info[[i]]$prior$mu +
                                 z99 * theta_info[[i]]$prior$sig)
    }

  }
  return (theta_info)
}