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
# This is the function to 
#           1. Sequentially propose candidate parameter values
#           2. Use M-H algorithm to accept or reject
#           3. Repeat for specified number of iterations

# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'

#===============================================================%
#     author: Matt Riddle										%
#     date: Feb 27, 2015										%
#===============================================================%

# GASPMCMC Generate realizations from a posterior distribution
#
#          Use this function to:
#           1. Sequentially propose candidate parameter values
#           2. Use M-H algorithm to accept or reject
#           3. Repeat for specified number of iterations

# CALLS: logpost.R, gendist.R, gaspchcov.R, gaspcovTri.R, genUTInds.R, genRectInds.R
# CALLED BY: runmcmc.R

#==============================================================%
#                        REQUIRED INPUTS                       %
#==============================================================%
# params structure containing information on:
#   theta: initial value for true calibration parameter value
#   beta_eta, lambda_eta: initial values for parameters for eta 
#   beta_b, lambda_b: initial values for parameters for bias
#   lambda_e: initial value of precision parameter for observation 
#             error
#   lambda_en: initial value of precision parameter for random error
#   theta_w: step width for generating candidate theta values
#   rho_eta_w: step width for generating candidate beta_eta values
#              rho_eta = exp(-beta_eta/4)
#   lambda_eta_w: step width for generating candidate lambda_eta values
#   rho_b_w: step width for generating candidate beta_b values
#            rho_b = exp(-beta_b/4)
#   lambda_b_w: step width for generating candidate lambda_b values
#   lambda_e_w: step width for generating candidate lambda_e values
#   lambda_en_w: step width for generating candidate lambda_en values
#   p: dimension of xf (xc)
#   q: dimension of theta (tc)
#   pq: p + q
#   n: number of field experiments
#   z: full set of inputs [(xf,theta);(xc,tc)]
#   nparms: number of parameters (including hyperparameters)
#   nmcmc: number of iterations of MCMC algorithm

#===============================================================%
#                           OUTPUTS                             %
#===============================================================%
# pvals: posterior realizations for parameters and hyperparameters
#        Each row is a realization from the posterior distribution 
#        and each column corresponds to a parameter, hyperparameter
#        or the log-likelihoods and log-posterior values 
#        parameter posteriors are transformed onto 0-1 scale
#        order of parameters and hyperparameters: theta(q), 
#        beta_eta(p+q), beta_b(q), lambda_eta, lambda_en, lambda_b, 
#        lambda_e
#        then columns for log-posterior and log-likelihood

# COMMENTS: See model description below for more information on
#           how candidate values are generated and accepted/rejected.


#===============================================================%
#                          MODEL DETAILS                        %
#===============================================================%
  
# M-H algorithm for generating candidate values and accepting
# or rejecting:
  
# From current parameter value a0, generate candidate
# a1 ~ UNIF(a0 - .5w, a0 + .5w) where w is specified step width

# lpost0 = logpost(a0) ... value of logposterior distribution at a0
# lpost1 = logpost(a1) ... value of logposterior distribution at a1

# pi = lpost1 - lpost0
# if pi > 0: always accept a1
# if pi < 0: accept a1 with probability pi
#            stay at a0 with probability 1-pi

#===============================================================%
  
gaspmcmc = function(params, verbose = 0, randseed = 0){
  
  
  theta_w = params$theta_w;
  rho_eta_w = params$rho_eta_w;
  lambda_eta_w = params$lambda_eta_w;
  rho_b_w = params$rho_b_w;
  lambda_b_w = params$lambda_b_w;
  lambda_e_w = params$lambda_e_w;
  lambda_en_w = params$lambda_en_w;
  numy = params$numy;
  q = params$q;
  pq = params$pq;
  n = params$n;
  p = params$p;
  nparms = params$nparms;
  nmcmc = params$nmcmc;
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Storage for posterior realizations
  pvals <- matrix (0, nrow = nmcmc, ncol=nparms+2)    #indi=zeros(inds,1);
  
# use adjparams to store the information that changes each run. The amount stored here should
# be kept small to speed up run times, since it gets copied frequently
  theta0 = params$theta;
  z0 <- params$z
  hyperparams0 = list();
  for (i in 1:numy){
    hyperparams0[[i]] = list()
    hyperparams0[[i]]$beta_eta = params$beta_eta[[i]];
    hyperparams0[[i]]$lambda_eta = params$lambda_eta[[i]];
    hyperparams0[[i]]$lambda_en = params$lambda_en[[i]];
    hyperparams0[[i]]$beta_b = params$beta_b[[i]];
    hyperparams0[[i]]$lambda_b = params$lambda_b[[i]];
    hyperparams0[[i]]$lambda_e = params$lambda_e[[i]];
  }  

  # Start MCMC ...

  print(sprintf('First Calculation...'))


  # Evaluate logpost at params0

  #calculate distance structures for z
  distztl <- gendist(params$z, params$ztlInds) # distance structure for top left part of z
  distztr <- gendist(params$z, params$ztrInds) # distance structure for top right part of z
  distzbr <- gendist(params$z, params$zbrInds) # distance structure for bottom right part of z

  #combine distance structures for different parts of z
  distz0 <- list()
  distz0$n <- nrow(params$z)
  distz0$d <- rbind(distztl$d, distztr$d, distzbr$d)
  
  #calculate upper triangular part of covariance matrix sigma_eta from distance structure
  # it is saved as a vector with only upper triangular entries to reduce size
  sigma_eta_tri0 = list()
  lpost0 = list()
  lpost0$thetaPrior = logpriortheta(theta0, params$theta_info);
  lpost0$tot = lpost0$thetaPrior;
  lpost0$likelihood = list()
  lpost0$hyperPrior = list()
  for (i in 1:numy){
    sigma_eta_tri0[[i]] = gaspcovTri(distz0$d,hyperparams0[[i]]$beta_eta,hyperparams0[[i]]$lambda_eta);
    #calculate full covariance matrix and do cholesky decomposition (to speed up taking inverse)
    sigmayCh <- gaspchcov(distz0, hyperparams0[[i]], params, sigma_eta_tri0[[i]])
    #pull out ith column of y
    yi <- as.matrix(params$y[,i])  
    #calculate log posterior value
    lpost0$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
    lpost0$hyperPrior[[i]] = logprior(hyperparams0[[i]]);
    lpost0$tot = lpost0$tot + lpost0$likelihood[[i]] + lpost0$hyperPrior[[i]]
  }

  # make a copy of the hyperparameters, parameters (theta), z, distance structure, 
  # and sigma_eta_tri, so that previous version can be restored if updates are 
  # rejected in MH acceptance step
  hyperparams1 = hyperparams0;
  theta1 = theta0;
  lpost1 = lpost0;
  z1 <- z0
  distz1 <- distz0
  sigma_eta_tri1 <- sigma_eta_tri0
  if (verbose == 1){
    print(sprintf('randseed = %d',randseed));
  }
    
  print(sprintf('Looping, n = %d ...', nmcmc));
  if (randseed == 0) {
    set.seed(NULL)          # if randseed = 0 that means turn off seed setting by saving NULL
  } else {
    set.seed(randseed)      # set the random number seed to the passed value
  }
  
  

  
  for (iter in 1:nmcmc){
  
    # UPDATE theta
    for (k in 1:q){
      
      theta1_k = theta0[k] + runif(1, -0.5, 0.5)*theta_w[k];
      #theta1_k <- 0.547208552958977 #used as a test to match matlab in first iteration
      # CHECK valid support
      if ((theta1_k > -0.0) && (theta1_k < 1.0)){
        theta1[k] = theta1_k;
        #fist n rows of z (corresponding to observed data) are assigned new parameter values
        z1[1:n,p+k] = theta1_k;
        
        #recalculate distance structure only for parts that change
        dtemp = gendist(as.matrix(z1[,p+k]), params$ztrInds);
        #assign new values to full distance structure
        distz1$d[params$distztrInds, p+k] <- dtemp$d
        lpost1$thetaPrior = logpriortheta(theta1, params$theta_info);
        lpost1$tot = lpost1$thetaPrior;
        for (i in 1:numy){
                                  
          #calculate upper triangular part of covariance matrix sigma_eta from distance structure
          # it is saved as a vector with only upper triangular entries to reduce size
          # only recalculate the top right, since that's all that has changed
          sigma_eta_tri1[[i]][params$distztrInds] = gaspcovTri(distz1$d[params$distztrInds,],hyperparams1[[i]]$beta_eta,hyperparams1[[i]]$lambda_eta);
          #calculate full covariance matrix and do cholesky decomposition (to speed up taking inverse)
          sigmayCh <- gaspchcov(distz1, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
          #pull out ith column of y
          yi <- as.matrix(params$y[,i])  
          # Evaluate logpost at new value
          lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
          lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
          lpost1$tot = lpost1$tot + lpost1$likelihood[[i]] + lpost1$hyperPrior[[i]]
        }
        
        criteria = log(runif(1,0,1))

        #the commented out version matches the matlab code, to allow direct comparison of results
        #accept = TRUE
        #for (i in 1:numy){
        #  lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]+lpost1$thetaPrior
        #  lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]+lpost0$thetaPrior
        #  if (criteria > (lpost1_comb[1] - lpost0_comb[1])){
        #    accept = FALSE
        #  }
        #}
        
        accept = FALSE
        if (criteria < (lpost1$tot[1] - lpost0$tot[1])){
          accept = TRUE
        }
        
        # M-H acceptance step
        #if (log(runif(1, 0, 1)) < (lpost1[1] - lpost0[1])){
        if (accept){
          lpost0 = lpost1;
          theta0 = theta1;
          z0 = z1;
          distz0 <- distz1
          sigma_eta_tri0 <- sigma_eta_tri1
        } else{
          lpost1 = lpost0;
          theta1 = theta0;
          z1 = z0;
          distz1 <- distz0
          sigma_eta_tri1 <- sigma_eta_tri0
        }
      }
    }
    
    for (i in 1:numy){
      # UPDATE beta_eta
      rho_eta = exp(-hyperparams0[[i]]$beta_eta/4);
      for (k in 1:pq){
        rho1_k = rho_eta[k] + runif(1, -0.5, 0.5)*rho_eta_w[[i]][k];
        # CHECK valid support
        if ((rho1_k > 0) && (rho1_k < 1)){
          beta1_k = -4*log(rho1_k);
          hyperparams1[[i]]$beta_eta[k] = beta1_k;
  
          #calculate upper triangular part of covariance matrix sigma_eta from distance structure
          # it is saved as a vector with only upper triangular entries to reduce size
          sigma_eta_tri1[[i]] = gaspcovTri(distz0$d,hyperparams1[[i]]$beta_eta,hyperparams1[[i]]$lambda_eta);
          #calculate full covariance matrix and do cholesky decomposition
          sigmayCh <- gaspchcov(distz0, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
          
          #pull out ith column of y
          yi <- as.matrix(params$y[,i])  
          # Evaluate logpost at new value
          lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
          lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
          lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]
          lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]
          lpost1$tot = lpost0$tot + lpost1_comb - lpost0_comb
          #lpost1 = logpost(sigmayCh, adjparams1, params);
          # M-H acceptance step
          if (log(runif(1, 0, 1)) < (lpost1_comb[1] - lpost0_comb[1])){
            lpost0 = lpost1;
            hyperparams0[[i]] = hyperparams1[[i]];
            sigma_eta_tri0[[i]] <- sigma_eta_tri1[[i]]
          } else{
            lpost1 = lpost0;
            hyperparams1[[i]] = hyperparams0[[i]];
            sigma_eta_tri1[[i]] <- sigma_eta_tri0[[i]]          
          }
        }
      }
      
      # UPDATE beta_b
      rho_b = exp(-hyperparams0[[i]]$beta_b/4);
      for (k in 1:p){
        rho1_k = rho_b[k] + runif(1, -0.5, 0.5)*rho_b_w[[i]][k];
        # CHECK valid support
        if ((rho1_k > 0) && (rho1_k < 1)){
          beta1_k = -4*log(rho1_k);
          hyperparams1[[i]]$beta_b[k] = beta1_k;
          
          #calculate full covariance matrix and do cholesky decomposition
          sigmayCh <- gaspchcov(distz0, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
          
          #pull out ith column of y
          yi <- as.matrix(params$y[,i])  
          # Evaluate logpost at new value
          lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
          lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
          lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]
          lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]
          lpost1$tot = lpost0$tot + lpost1_comb - lpost0_comb
          #lpost1 = logpost(sigmayCh, adjparams1, params);
          # M-H acceptance step
          if (log(runif(1, 0, 1)) < (lpost1_comb[1] - lpost0_comb[1])){
            lpost0 = lpost1;
            hyperparams0[[i]] = hyperparams1[[i]];
          } else{
            lpost1 = lpost0;
            hyperparams1[[i]] = hyperparams0[[i]];
          }
        }
      }
      
      # UPDATE lambda_eta
      lambda_eta1 = hyperparams0[[i]]$lambda_eta + runif(1, -0.5, 0.5)*lambda_eta_w[[i]];
      # CHECK valid support
      if (lambda_eta1 > 0){
        hyperparams1[[i]]$lambda_eta = lambda_eta1;
        
        #calculate upper triangular part of covariance matrix sigma_eta from distance structure
        # it is saved as a vector with only upper triangular entries to reduce size
        sigma_eta_tri1[[i]] = gaspcovTri(distz0$d,hyperparams1[[i]]$beta_eta,hyperparams1[[i]]$lambda_eta);
        #calculate full covariance matrix and do cholesky decomposition
        sigmayCh <- gaspchcov(distz0, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
        
        #pull out ith column of y
        yi <- as.matrix(params$y[,i])  
        # Evaluate logpost at new value
        lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
        lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
        lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]
        lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]
        lpost1$tot = lpost0$tot + lpost1_comb - lpost0_comb
        #lpost1 = logpost(sigmayCh, adjparams1, params);
        # M-H acceptance step
        if (log(runif(1, 0, 1)) < (lpost1_comb[1] - lpost0_comb[1])){
          lpost0 = lpost1;
          hyperparams0[[i]] = hyperparams1[[i]];
          sigma_eta_tri0[[i]] <- sigma_eta_tri1[[i]]
        } else{
          lpost1 = lpost0;
          hyperparams1[[i]] = hyperparams0[[i]];
          sigma_eta_tri1[[i]] <- sigma_eta_tri0[[i]]          
        }

      }
      
      # UPDATE lambda_en
      lambda_en1 = hyperparams0[[i]]$lambda_en + runif(1, -0.5, 0.5)*lambda_en_w[[i]];
      # CHECK valid support
      if (lambda_en1 > 0){      
        hyperparams1[[i]]$lambda_en = lambda_en1;
        
        #calculate full covariance matrix and do cholesky decomposition
        sigmayCh <- gaspchcov(distz0, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
        
        #pull out ith column of y
        yi <- as.matrix(params$y[,i])  
        # Evaluate logpost at new value
        lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
        lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
        lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]
        lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]
        lpost1$tot = lpost0$tot + lpost1_comb - lpost0_comb
        #lpost1 = logpost(sigmayCh, adjparams1, params);
        # M-H acceptance step
        if (log(runif(1, 0, 1)) < (lpost1_comb[1] - lpost0_comb[1])){
          lpost0 = lpost1;
          hyperparams0[[i]] = hyperparams1[[i]];
        } else{
          lpost1 = lpost0;
          hyperparams1[[i]] = hyperparams0[[i]];
        }
      }
      
      # UPDATE lambda_b
      lambda_b1 = hyperparams0[[i]]$lambda_b + runif(1, -0.5, 0.5)*lambda_b_w[[i]];
      # CHECK valid support
      if (lambda_b1 > 0){
        hyperparams1[[i]]$lambda_b = lambda_b1;
        
        #calculate full covariance matrix and do cholesky decomposition
        sigmayCh <- gaspchcov(distz0, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
        
        #pull out ith column of y
        yi <- as.matrix(params$y[,i])  
        # Evaluate logpost at new value
        lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
        lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
        lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]
        lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]
        lpost1$tot = lpost0$tot + lpost1_comb - lpost0_comb
        #lpost1 = logpost(sigmayCh, adjparams1, params);
        # M-H acceptance step
        if (log(runif(1, 0, 1)) < (lpost1_comb[1] - lpost0_comb[1])){
          lpost0 = lpost1;
          hyperparams0[[i]] = hyperparams1[[i]];
        } else{
          lpost1 = lpost0;
          hyperparams1[[i]] = hyperparams0[[i]];
        }

      }
      
      # UPDATE lambda_e
      lambda_e1 = hyperparams0[[i]]$lambda_e + runif(1, -0.5, 0.5)*lambda_e_w[[i]];
      # CHECK valid support
      if (lambda_e1 > 0){
        hyperparams1[[i]]$lambda_e = lambda_e1;
        
        #calculate full covariance matrix and do cholesky decomposition
        sigmayCh <- gaspchcov(distz0, hyperparams1[[i]], params, sigma_eta_tri1[[i]])
        
        #pull out ith column of y
        yi <- as.matrix(params$y[,i])  
        # Evaluate logpost at new value
        lpost1$likelihood[[i]] = loglikelihood(sigmayCh, yi) 
        lpost1$hyperPrior[[i]] = logprior(hyperparams1[[i]]);
        lpost1_comb = lpost1$likelihood[[i]]+lpost1$hyperPrior[[i]]
        lpost0_comb = lpost0$likelihood[[i]]+lpost0$hyperPrior[[i]]
        lpost1$tot = lpost0$tot + lpost1_comb - lpost0_comb
        #lpost1 = logpost(sigmayCh, adjparams1, params);
        # M-H acceptance step
        if (log(runif(1, 0, 1)) < (lpost1_comb[1] - lpost0_comb[1])){
          lpost0 = lpost1;
          hyperparams0[[i]] = hyperparams1[[i]];
        } else{
          lpost1 = lpost0;
          hyperparams1[[i]] = hyperparams0[[i]];
        }
      }
    }    
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    lpost0TotCheck = lpost0$thetaPrior
    for (i in 1:numy){
      lpost0TotCheck = lpost0TotCheck + lpost0$likelihood[[i]] + lpost0$hyperPrior[[i]]
    }
    
    pvals_row = c(theta0)
    for (i in 1:numy){
      pvals_row = c(pvals_row, t(hyperparams0[[i]]$beta_eta), t(hyperparams0[[i]]$beta_b), hyperparams0[[i]]$lambda_eta, hyperparams0[[i]]$lambda_en, hyperparams0[[i]]$lambda_b, hyperparams0[[i]]$lambda_e);
    }
    pvals_row = c(pvals_row, lpost0$tot[1], lpost0$tot[2])
    pvals[iter,] = pvals_row
    # Display iteration results on screen
    if (iter%%5 == 0){  
      print(sprintf('%4d: ',iter));
      #     fprintf(' %4.2f',pvals(iter,:));
      #        fprintf('\n');
    }
      
  }  
  return (pvals)
}