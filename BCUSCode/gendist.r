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
#            1. Store information on size of original design matrix
#            2. Create and store distance array

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'

#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%

# GENDIST Function to create a distance structure

#         Use this function to:
#            1. Store information on size of original design matrix
#            2. Create and store distance array

# CALLED BY: etaxpred.R, yxpred.R, gaspmcmc.R, setupParams.R

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# x: design matrix (n x p)
# inds: a list of coordinates of the distance matrix to generate
#   distances for (generate distance between ith row and jth row
#   of the design matrix

#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# dist data structure containing
#     n: number of rows in design matrix
#     d: length(inds)xp distance matrix obtained as
#        (xik - xjk)^alpha for all pairs of rows (i,j) in inds

# COMMENTS: Generally assume alpha = 2
#===============================================================%


gendist <- function (x, inds)
{
  dist = list ();
  dist$n = dim(x) [1];
  # Create distance array with alpha = 2
  #alpha = 2;
  dist$d = (x[inds$j,] - x[inds$i,]) ^ 2;  # d.d=(data(indj,:)-data(indi,:)).^alpha;
 
  return (dist);
}

