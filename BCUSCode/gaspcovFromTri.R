#                    Copyright © 201? , UChicago Argonne, LLC
#                              All Rights Reserved
#                          [Software Name, Version 1.x??]
#                   [Optional:  Authors name and organization}
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
# This is the function to convert covariance matrix from triangular to matrix form

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'

#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%
 
# GASPCOVFromTri Generate full GASP covariance matrix from trangular form
#
#         Use this function to:
#           1. Convert covariance matrix from triangular to matrix form
#
# CALLED BY: gaspchcov.R, etaxpred.R, yxpred.R

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# n: original dimension of design matrix
# odut: indices of off-diagonal-upper-triangle elements of
#         an nxn matrix
# odlt: indices of off-diagonal-lower-triangle elements of
#         an nxn matrix
# lam: precision parameter
# tri: containing values for upper and lower triangular cov matrix
#   in vector form (length {n choose 2} distance matrix (x(k)-x'(k))^alpha

                                           
#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# sigma: GASP covariance matrix  (n x n)
                                           
#===============================================================%
#                          MODEL DETAILS                        %
#===============================================================%
                                           
# sigma = 1/lam C(x,x')
# C(x,x') = exp{-sum_{k=1:p}beta(k)(x(k)-x'(k))^alpha}

# COMMENTS: Generally assume alpha = 2

#===============================================================#

gaspcovFromTri <- function(n, odut, odlt, lam, tri){
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Specify size of covariance matrix corresponding to design matrix
  sigma <- matrix (0, nrow = n, ncol=n);    #indi=zeros(inds,1);
  
  # Set upper triangle of C(x,x')
  sigma[odut] = tri;
  
  # Set lower triangle of C(x,x')
  sigma[odlt] = tri;
  
  # Set diagonal elements of C(x,x')
  diags = 1:n
  diags <- diags * (n+1) - n
  sigma[diags] = 1/lam;
  
  return(sigma)
}
