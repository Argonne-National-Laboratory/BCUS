# BCUS Bayesian Calibration, Uncertainty, and Sensitivity
BCUS: Bayesian Calibration, Uncertainty, and Sensitivity is a cross platform set of Ruby and R scripts to support sensitivity analysis, uncertainty analysis, and Bayesian calibration of OpenStudio energy models.

Tutorials explaining installation and use of BCUS are found within the tutorials directory

The software has been developed in Windows 7 and has been tested on OS-X El Capitan

## Installation

###BCUS has the following dependencies

* OpenStudio (>=1.11) with Ruby 2.0 bindings and EnergyPlus
* Ruby 2.0
* Ruby Gems: rubyXL
* R (>=3.1.0)
* R packages: sensitivity, ggplot2, lhs, car, triangle, gridextra 

### Basic Installation
* Copy the BCUSCode directory to your location of choice and set the environmental variables as described below
* Copy the Example folder and modify the files for your particular project



### Environmental Variables
You need to set up ruby to 

set the environmental variable "BCUSCODE" to the path to the directory BCUSCode and add the same directory to your rubypath

For example.  On a Windows system where BCUSCode is in C:\BCUS\BCUSCode you would set the following
set BCUSCODE=C:\BCUS\BCUSCode
set RUBYPATH=C:\BCUS\BCUSCode;%RUBYPATH%

## Usage

## Testing

## Caveats and Todos

## Contributing
1. Fork it (https://github.com/Argonne-BEDTR/BCUS/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
6. Wait a while until we find time to review the Pull Request






