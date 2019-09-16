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

#===============================================================%
#     author: Matt Riddle                                       %
#     date: Feb 27, 2015										                    %
#===============================================================%


# readFromParamFile: Reads parameter info from file

# CALLED BY: runmcmc.R

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


# setupParams: sets up the params data structure used in GASPmcmc
#
#            Use this function to:
#               1. Read computer and field data from files
#               2. Standardize data
#               3. Put design on [0,1]
#               4. SPECIFY initial parameter values
#               5. SPECIFY M-H stepwidths
#               6. Generate index structures used in MCMC step
#               7. Generate fixed distance structures for X

# CALLS: gendist.R

#==============================================================#
#                        REQUIRED INPUTS                       #
#==============================================================#
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
# com_filename: name for file with info results of computer model runs
#   first columns (# columns specified in numYVars): model output 
#   next columns (# columns specified in numXVars): 
#     values for x (e.g., weather) variables used in model runs
#   remaining columns (# columns should match number of rows in params_filename): 
#     values for theta parameters used in model runs
#
# field_filename: name for file info on observed data used for calibration
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
# COMMENTS: This program does all the necessary standardization...
#           Simply input raw values.

#===============================================================#
#                           OUTPUTS                             #
#===============================================================#
# params: structure containing data and parameter information
#   Parameter structure holds data information, initial parameter 
#   values, covariance matrix, and stepwidths for MCMC

setupParams <- function(theta_info, com_filename, field_filename,
                        numYVars, numXVars, numMCMCSteps, verbose) {
  # library("gridExtra")
  if (verbose == 1) {
    message(sprintf("com_filename = %s", com_filename))
    message(sprintf("field_filename = %s", field_filename))
  	message(sprintf("numYvars = %s", numYVars))
  	message(sprintf("numbXvars = %s", numXVars))
  }
  
  DATACOMP <- read.csv(com_filename, header=FALSE, sep="\t")
  DATACOMP <- as.matrix(DATACOMP)
  
  DATAFIELD <- read.csv(field_filename, header=FALSE, sep="\t")
  DATAFIELD <- as.matrix(DATAFIELD)
    
  numTheta <- length(theta_info)
  
  yInds <- 1:numYVars
  xInds <- (numYVars+1):(numYVars+numXVars)
  thetaInds <- (numYVars+numXVars+1):(numYVars+numXVars+numTheta)
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # xf: Design points corresponding to field trials
  xf <- DATAFIELD[, xInds, drop=FALSE]
  
  # ADDITION FOR THE USE OF PERIODICITY, DATA SHOULD BE REPARAMETRIZED OF TIME 
  
  # (xc,tc): Design points corresponding to computer trials
  # tc is calibration parameters
  xc <- DATACOMP[, xInds, drop=FALSE]
  tc <- DATACOMP[, thetaInds, drop=FALSE]
  
  # yf: Response from field experiments
  # yc: Response from computer simulations
  yf <- DATAFIELD[, yInds, drop=FALSE]
  yc <- DATACOMP[, yInds, drop=FALSE]
  
  
  # Obtain dimensions of inputs
  numy <- dim(yf)[2]
  n <- dim(xf)[1]
  p <- dim(xf)[2]
  m <- dim(xc)[1]
  p <- dim(xc)[2]
  m <- dim(tc)[1]
  q <- dim(tc)[2]
  pq <- p + q
  nm <- n + m
  # Standardize full response using mean and std of yc
  y <- rbind(yf, yc)
  ym <- apply(yc, 2, mean)  
  ysd <- apply(yc, 2, sd) 
  
  ymmat <- matrix(rep(ym, each = nrow(y)), nrow(y), numy)
  ysdmat <- matrix(rep(ysd, each = nrow(y)), nrow(y), numy)

  y <- (y-ymmat) / ysdmat
  # checks:
  # apply(y[(n+1):nm,], 2, mean) #should be 0s
  # apply(y[(n+1):nm,], 2, sd)   #should be 1s
  
  # Put design points xf and xc on [0,1]:
  # Stack together fields design points and computer design 
  # points for standardization
  xx <- rbind(xf, xc)
  xmin = apply(xx, 2, min)
  xmax = apply(xx, 2, max)
  for (k in 1:p) {
    xf[, k] <- (xf[, k] - xmin[k]) / (xmax[k] - xmin[k])
    xc[, k] <- (xc[, k] - xmin[k]) / (xmax[k] - xmin[k])
  }
  # Put calibration inputs tc on [0,1]
  # Also transform prior distribution parameters to be on
  # same scale
  
  # min and max are now values passed in instead of actual min and max
  # from data 
  # (original matlab code was: tmin = min(tc) tmax = max(tc))
  for(k in 1:q) {
    tmin <- theta_info[[k]]$min
    tmax <- theta_info[[k]]$max
    tc[,k] <- (tc[,k] - tmin) / (tmax - tmin)
    if (theta_info[[k]]$prior$type == "triangular") {
      theta_info[[k]]$prior$min <-
        (theta_info[[k]]$prior$min - tmin) / (tmax - tmin)
      theta_info[[k]]$prior$max <-
        (theta_info[[k]]$prior$max - tmin) / (tmax - tmin)
      theta_info[[k]]$prior$mode <-
        (theta_info[[k]]$prior$mode - tmin) / (tmax - tmin)
    } else if (theta_info[[k]]$prior$type == "uniform") {
      theta_info[[k]]$prior$min <-
        (theta_info[[k]]$prior$min - tmin) / (tmax - tmin)
      theta_info[[k]]$prior$max <-
        (theta_info[[k]]$prior$max - tmin) / (tmax - tmin)
    } else if (theta_info[[k]]$prior$type == "normal") {
      theta_info[[k]]$prior$mean <-
        (theta_info[[k]]$prior$mean - tmin) / (tmax - tmin)
      theta_info[[k]]$prior$stDev <-
        (theta_info[[k]]$prior$stDev) / (tmax - tmin)      
    } else if (theta_info[[k]]$prior$type == "lognormal") {
      # need to check that this is right
      theta_info[[k]]$prior$mu <- theta_info[[k]]$prior$mu - log(tmax)
    } else {
      cat('distribution type', theta_info[[k]]$prior$type, 'not found')
    }
  }
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Create a structure to pass on to functions...
  # Parameter structure holds data information, initial parameter 
  # values, covariance matrix, and stepwidths for MCMC
  
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX#
  # SPECIFY INITIAL PARAMETER VALUES HERE !!!!#
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX#
  params <- list()
  params$theta <- matrix(0.5, 1, q)
  
  params$beta_eta <- list()
  params$lambda_eta <- list()
  params$beta_b <- list()
  params$lambda_b <-list()
  params$lambda_e <- list()
  params$lambda_en <- list()

  for (i in 1:numy){
    params$beta_eta[[i]] <- matrix(0.5, pq, 1)
    params$lambda_eta[[i]] <- 1
    params$beta_b[[i]] <- matrix(0.2, p, 1)
    params$lambda_b[[i]] <- 10
    params$lambda_e[[i]] <- 1
    params$lambda_en[[i]] <- 300
  }
  
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXX#
  # SPECIFY STEP WIDTHS HERE !!!#
  #XXXXXXXXXXXXXXXXXXXXXXXXXXXXX#
  params$theta_w <- matrix(0.15, q, 1)

  params$rho_eta_w <- list()
  params$lambda_eta_w <- list()
  params$rho_b_w <- list()
  params$lambda_b_w <- list()
  params$lambda_e_w <- list()
  params$lambda_en_w <- list()

  for (i in 1:numy){
    params$rho_eta_w[[i]] <- matrix(0.15, pq, 1) # rho_eta = exp(-beta_eta/4)
    params$lambda_eta_w[[i]] <- 1
    params$rho_b_w[[i]] <- matrix(0.15, p, 1) # rho_b = exp(-beta_b/4)
    params$lambda_b_w[[i]] <- 5
    params$lambda_e_w[[i]] <- 1
    params$lambda_en_w[[i]] <- 100
  }
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  params$nmcmc <- numMCMCSteps

  params$y <- y #transformed
  params$yf <- yf #before transformation
  params$x <- xf # design points corresponding
  # to field trials
  topright <- array(rep(params$theta, n), dim = c(n, dim(params$theta)[2]))
  top <- cbind(xf, topright)
  bottom <- cbind(xc, tc)
  names(top) <- names(bottom) 
  params$z <- rbind(top, bottom)
  
  # full set of inputs
  # z = (xf,theta) for field trials
  # z = (xc,tc) for computer simulations  
  params$xc <- xc# scaled design points corresponding to 
  # computer simulations
  params$tc <- tc# scaled calibration parameter inputs to
  # computer code
  params$numy <- numy
  params$n <- n
  params$p <- p
  params$m <- m
  params$q <- q
  params$pq <- pq # p+q
  params$nm <- nm # n+m
  params$ym <- ym # mean of model response
  params$ysd <- ysd # standard deviation of model response
  params$xmin <- xmin # minimum values of x
  params$xmax <- xmax # maximum values of x
  params$theta_info <- theta_info
  params$nparms <- q + numy*(pq + p + 4) # number of parameters
  
  # x has n rows, z has n+m rows (top n are opserved, bottom m are computer)
  # so covariance matrix for x is nxn and for z is (n+m)x(n+m)
  # covariance matrix for z can be broken into top left (nxn), top right (nxm)
  # bottom left (mxn) and bottom right (mxm)
  # the top left and bottom right can be broken into diagonal, off-diagonal
  # upper triangular and off-diagonal lower triangular
  # it is useful to separate it out, because only parts of it need
  # to be recalculated each period
  
  # generate indices for x and for off diagonal upper triangular part
  # of the top left and 
  # bottom right and all indices of the top right of z
  # these indices include a row (inds$i) and a column (inds$j) index
  topInds <- 1:params$n
  bottomInds <- (params$n+1):(params$n+params$m)
  params$xInds <- genODUTInds(topInds)
  params$ztlInds <- genODUTInds(topInds)
  params$ztrInds <- genRectInds(topInds, bottomInds)
  params$zbrInds <- genODUTInds(bottomInds)
  
  # generate vector versions of the row and column indices generated above
  # also generate equivalent lower triangular indices
  # by reversing row and column
  
  params$distx_odut <- params$xInds$i + nrow(params$x) * (params$xInds$j-1)  
  zODUTtlIndsVect <- params$ztlInds$i + nrow(params$z) * (params$ztlInds$j-1)  
  zODUTtrIndsVect <- params$ztrInds$i + nrow(params$z) * (params$ztrInds$j-1)  
  zODUTbrIndsVect <- params$zbrInds$i + nrow(params$z) * (params$zbrInds$j-1)  
  zODLTtlIndsVect <- params$ztlInds$j + nrow(params$z) * (params$ztlInds$i-1)  
  zODLTblIndsVect <- params$ztrInds$j + nrow(params$z) * (params$ztrInds$i-1)  
  zODLTbrIndsVect <- params$zbrInds$j + nrow(params$z) * (params$zbrInds$i-1)  
  #combine indices for different parts of z
  params$distz_odutUT <- c(zODUTtlIndsVect, zODUTtrIndsVect, zODUTbrIndsVect)
  params$distz_odutLT <- c(zODLTtlIndsVect, zODLTblIndsVect, zODLTbrIndsVect)
  
  #calculate distance structures for x
  params$distx <- gendist(params$x, params$xInds) # distance structure for xf  

  #these calculations are done in gaspmcmc, and shouldn't need to be done here
  #they're only used for their num rows in the ztrInds calc below
  # distance structure for top left part of z
  distztl <- gendist(params$z, params$ztlInds)
  # distance structure for top right part of z
  distztr <- gendist(params$z, params$ztrInds)
  # distance structure for bottom left part of z
  distzbr <- gendist(params$z, params$zbrInds)

  #indices of the top right portion of covariance matrix in distz vector
  params$distztrInds <- (nrow(distztl$d)+1):(nrow(distztl$d)+nrow(distztr$d))

  return(params)
}


# GenODUTInds Function to create row and column indices of
#   off-diagonal upper triangle

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# rcinds: a set of row and column indeces

#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# inds data structure containing
#     i: row indices of triangular structure
#     j: column indices of triangular structure

#===============================================================%

genODUTInds <- function(rcinds) {
  inds <- list()
  n <- length(rcinds)
  numinds = n * (n-1) / 2
  indi = matrix(0, nrow=numinds, ncol=1)    #indi=zeros(inds,1)
  indj = matrix(0, nrow=numinds, ncol=1)    # indj=zeros(inds,1)
  ind = 1
  for (ii in 1:(n-1)) {
    # print (paste ("indi[", ind, ":", ind + n - i2 - 1, "] = ", i2))
    indi[ind: (ind + n - ii - 1)] = rcinds[ii]
    indj[ind: (ind + n - ii - 1)] = rcinds[(ii + 1):n] 
    ind = ind + n - ii 
  }
  
  inds$i = indi  
  inds$j = indj  
  #inds$vec =indi + n*(indj-1)  
  return(inds)
}


# GenRectInds Function to create row and column indices of rectangle

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# rinds: a set of row indeces
# cinds: a set of column indices

#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# inds data structure containing
#     i: row indices of rectangular structure
#     j: column indices of rectangular structure

#===============================================================%

genRectInds <- function(rinds, cinds) {
  inds <- list()
  nr <- length(rinds)
  nc <- length(cinds)
  indi = rep(rinds, times=nc)
  indj = rep(cinds, each=nr)
  
  inds$i =indi;  
  inds$j =indj;  
  return(inds)
}
