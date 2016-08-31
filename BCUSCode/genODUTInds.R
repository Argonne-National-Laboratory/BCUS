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
# This is the function to create and store row and column indices of off diagonal upper triangle


# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'


#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%

# GenODUTInds Function to create row and column indices of
#   off-diagonal upper triangle
#

#         Use this function to:
#            1. Create and store row and column indices of 
#  off diagonal upper triangle

# CALLED BY: setupParams.R, runPred.R, yxpred.R

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

genODUTInds <- function(rcinds){
  inds <- list()
  n <- length(rcinds)
  numinds = n * (n-1) / 2;
  indi = matrix (0, nrow = numinds, ncol=1);    #indi=zeros(inds,1);
  indj = matrix (0, nrow = numinds, ncol=1);    # indj=zeros(inds,1);
  ind = 1;
  for (ii in 1:(n-1)){
    # print (paste ("indi[", ind, ":", ind + n - i2 - 1, "] = ", i2));
    indi [ind: (ind + n - ii - 1)] = rcinds[ii];
    indj [ind: (ind + n - ii - 1)] = rcinds[(ii + 1):n]; 
    ind = ind + n - ii; 
  }
  
  inds$i =indi;  
  inds$j =indj;  
  #inds$vec =indi + n*(indj-1);  
  return(inds)
}