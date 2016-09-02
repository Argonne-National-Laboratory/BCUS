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
# This is the function to evaluate GASP covariance matrix, save triangular part in vector form

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'


#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%

# GASPCOV Generate triangular part of GASP covariance matrix 
#
#         Use this function to:
#           1. Evaluate GASP covariance matrix, save triangular 
#              part in vector form

# CALLED BY: gaspmcmc.R, etaxpred.R, yxpred.R

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# d: ({n choose 2} x p) distance matrix (x(k)-x'(k))^alpha
#      for an n x p design matrix x

# beta: parameters for strength of dependencies
                                           
# lam: precision parameter
                                           
#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# sigmaTri: vector length {n choose 2} with off-diagonal upper
#   triangular portion of nxn GASP covariance matrix 
                                           
#===============================================================%
#                          MODEL DETAILS                        %
#===============================================================%
                                           
# sigma = 1/lam C(x,x')
# C(x,x') = exp{-sum_{k=1:p}beta(k)(x(k)-x'(k))^alpha}

# COMMENTS: Generally assume alpha = 2

#===============================================================#

gaspcovTri <- function(d, beta, lam){

  #n = dist$n;
  #d = dist$d;
  #odut = dist$odut;

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Specify size of covariance matrix corresponding to design matrix
  #sigma <- matrix (0, nrow = n, ncol=n);    #indi=zeros(inds,1);

  #temp1 <- exp(-d%*%beta)/lam
  # Set upper triangle of C(x,x')
  sigmaTri = exp(-d%*%beta)/lam;

  return(sigmaTri)
}
