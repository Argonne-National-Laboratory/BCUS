=begin of comments
Copyright © 201? , UChicago Argonne, LLC
All Rights Reserved
 [Software Name, Version 1.x??]
[Optional:  Authors name and organization}
OPEN SOURCE LICENSE

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.  Software changes, modifications, or derivative works, should be noted with comments and the author and organization’s name.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

4. The software and the end-user documentation included with the redistribution, if any, must include the following acknowledgment:

   "This product includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.”

******************************************************************************************************
DISCLAIMER

THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

***************************************************************************************************


Modified Date and By:
- Created on July 2015 by Yuna Zhang from Argonne National Laboratory


1. Introduction
This is the subfunction called by Uncertain_Parameters to generate boilder efficiency uncertainty distribution.

=end


class BoilerUncertainty < OpenStudio::Model::Model
  attr_reader :boiler_name
  attr_reader :boiler_thermal_efficiency

  def initialize

    @boiler_name = Array.new
    @boiler_thermal_efficiency =Array.new
  end

  def boiler_find(model)
    #loop through to find water boiler
    model.getBoilerHotWaters.each do |boiler_water|
      if not boiler_water.to_BoilerHotWater.empty?
        water_unit = boiler_water.to_BoilerHotWater.get
        @boiler_name << water_unit.name.to_s
        @boiler_thermal_efficiency << water_unit.nominalThermalEfficiency.to_f
        ## add else nil
      end
    end

    model.getBoilerSteams.each do |boiler_steam|
      unless boiler_steam.to_BoilerSteam.empty?
        steam_unit = boiler_steam.to_BoilerSteam.get
        @boiler_name << steam_unit.name.to_s
        @boiler_thermal_efficiency << water_unit.nominalThermalEfficiency.to_f
      end
    end
  end


  # find thermal efficiency for boiler
  def boiler_efficiency_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /HotWaterBoiler/
        model.getBoilerHotWaters.each do |boiler_water|
          unless boiler_water.to_BoilerHotWater.empty?
            water_unit = boiler_water.to_BoilerHotWater.get
            water_unit.setNominalThermalEfficiency(parameter_value[index])
          end
        end
      end
      if type =~ /SteamBoiler/
        model.getBoilerSteams.each do |boiler_steam|
          unless boiler_water.to_BoilerSteam.empty?
            steam_unit = boiler_steam.to_BoilerSteam.get
            steam_unit.setNominalThermalEfficiency(parameter_value[index])
          end
        end
      end
    end
  end

end