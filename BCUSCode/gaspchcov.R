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
# This is the function to generate cholesky factorization of model specific
# covariance matrix sigma_y

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'



#===============================================================%
#     author: Matt Riddle                                       %
#     date: Feb 27, 2015										                    %
#===============================================================%
  
# GASPCHCOV Function to generate cholesky factorization of model 
#           specific covariance matrix sigma_y

#           Use this function to:
#               1. Compile model-specific gasp covariance matrix
#               2. Obtain cholesky factorization 

# CALLS: gaspcov.R, gaspcovFromTri.R
# CALLED BY: gaspmcmc.R

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# distz.d: distance array corresponding to z = [(xf,theta)(xc,tc)]
# adjparams structure containing
#   beta_eta: dependence strength parameters for eta
#   lambda_eta: precision parameter for eta
#   lambda_en: precision parameter for random error en
#   beta_b: dependence strength parameters for bias
#   lambda_b: precision parameter for bias
#   lambda_e: precision parameter for observation error
# params structure containing
#   n: number of field experiments
#   nm: (n+m) total number of field and computer simulations
#   distx.d: distance array corresponding to xf
#   m: number of computer simulations
#   distz_odut: vector indices of off-diagonal upper triangular
#      part of z
#   distz_odlt: vector indices of off-diagonal lower triangular
#      part of z
#   distx_odut: vector indices of off-diagonal upper triangular
#      part of x
# sigma_eta_tri
#   pre-computed covariance matrix for eta function, stored in
#   vector form

#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# sigmayCh: Cholesky decomposition of (n+m) x (n+m) covariance
#           matrix sigma_y. sigmayCh is an upper triangular matrix 
#           such that sigmayCh'*sigmayCh = sigma_y.

#===============================================================%
#                          MODEL DETAILS                        %
#===============================================================%

# sigma_y = sigma_eta + |sigma_b    0| + |sigma_e      0    |
#                       |    0      0|   |   0     sigma_en |

# sigma_eta = gaspcov(distz, beta_eta, lambda_eta) --> (nm x nm)
# sigma_b = gaspcov(distx, beta_b, lambda_b) --> (n x n)
# sigma_e = diag[n](1/lambda_e)
# sigma_en = diag[m](1/lambda_en)

#===============================================================%

gaspchcov <- function(distz, hyperparams, params, sigma_eta_tri) {

  beta_eta = hyperparams$beta_eta
  lambda_eta = hyperparams$lambda_eta
  lambda_en = hyperparams$lambda_en
  beta_b = hyperparams$beta_b
  lambda_b = hyperparams$lambda_b
  lambda_e = hyperparams$lambda_e
  m = params$m
  n = params$n
  nm = params$nm
  distx = params$distx
  distz_odut = params$distz_odutUT
  distz_odlt = params$distz_odutLT
  distx_odut = params$distx_odut
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Evaluate (n+m) x (n+m) covariance matrix sigma_eta
  # triangular covariance matrix has already been calculated as vector - just
  # need to put it
  # in matrix form
  sigma_eta = gaspcovFromTri(distz$n, distz_odut, distz_odlt,
                              lambda_eta, sigma_eta_tri)
  # Evaluate (m x m) covariance matrix sigma_en, in vector form to save
  # calculation time
  # sigma_en = diag(1/lambda_en, m)
  sigma_enVec = rep(1/lambda_en, times=m)
  # Evalute (n x n) covariance matrix sigma_b
  sigma_b = gaspcov(distx, distx_odut, beta_b, lambda_b)

  # Evaluate (n x n) covariance matrix sigma_e
  sigma_e = diag(1/lambda_e, n)

  # Evaluate (n+m) x (n+m) covariance matrix sigma_y
  sigma_y = sigma_eta
  sigma_y[1:n, 1:n] = sigma_y[1:n, 1:n] + sigma_b + sigma_e
  # add sigma_en to bottom right diagonal
  diagIndsBR <- (n+1):nm + nm*(((n+1):nm)-1)
  sigma_y[diagIndsBR] = sigma_y[diagIndsBR] + sigma_enVec

  # Return Cholesky factorization of covariance matrix sigma_y
  sigmayCh <- chol(sigma_y)

  return(sigmayCh)
}
