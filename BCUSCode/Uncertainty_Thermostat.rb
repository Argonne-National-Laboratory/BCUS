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
# - Created on July 2016 by Yuna Zhang from Argonne National Laboratory

# 1. Introduction
# This is the subfunction called by uncertain_parameters to set uncertainty
# for thermostat
# Thermostat dual setpoint uncertainty works for SI unit only

# 2. Call structure
# Refer to 'Function Call Structure.pptx'

# Class to describe thermostat uncertainty
class ThermostatUncertainty < OpenStudio::Model::Model
  attr_reader :clg_set_sch_name
  attr_reader :htg_set_sch_name
  attr_reader :clg_set_sch_value
  attr_reader :htg_set_sch_value

  def initialize
    @clg_set_sch_name = []
    @clg_set_sch_value = []
    @htg_set_sch_name = []
    @htg_set_sch_value = []
  end

  def cooling_set(model, adjust_value, model_out)
    setpoint_set(model, 'cooling', adjust_value, model_out)
  end

  def heating_set(model, adjust_value, model_out)
    setpoint_set(model, 'heating', adjust_value, model_out)
  end

  def setpoint_set(model, conditioning, adjust_value, model_out)
    param_get, param_set =
      case conditioning
      when 'cooling'
        %w[
          coolingSetpointTemperatureSchedule
          setCoolingSetpointTemperatureSchedule
        ]
      when 'heating'
        %w[
          heatingSetpointTemperatureSchedule
          setHeatingSetpointTemperatureSchedule
        ]
      else
        [nil, nil]
      end

    return if param_get.nil?
    # Push schedules to hash to avoid making unnecessary duplicates
    set_schs = {}
    set_sch_names = []
    set_sch_values = []

    # Get thermostats and setpoint schedules
    thermostats = model.getThermostatSetpointDualSetpoints
    thermostats.each do |thermostat|
      # Setup new cooling setpoint schedule
      set_sch = thermostat.send(param_get.to_sym)
      next if set_sch.empty?
      # Clone of not alredy in hash
      if set_schs.key?(set_sch.get.name.to_s)
        set_sch_new = set_schs[set_sch.get.name.to_s]
      else
        set_sch_new = set_sch.get.clone(model).to_Schedule.get
        set_sch_new.setName("#{set_sch_new.name} adjusted")
        # Add to the hash
        set_schs[set_sch.get.name.to_s] = set_sch_new
      end
      # Hook up clone to thermostat
      thermostat.send(param_set.to_sym, set_sch_new)
    end

    # Old name and new object for schedule
    set_schs.each do |_k, v|
      set_sch_name = v.name.to_s
      next if v.to_ScheduleRuleset.empty?
      # Array to store profiles inules.each do |rule|
      profiles = []
      schedule = v.to_ScheduleRuleset.get
      # Push default profiles to array
      default_rule = schedule.defaultDaySchedule
      profiles << default_rule
      # Push profiles to array
      rules = schedule.scheduleRules
      rules.each do |rule|
        day_sch = rule.daySchedule
        profiles << day_sch
      end

      profiles.each do |sch_day|
        day_time_vector = sch_day.times
        day_value_vector = sch_day.values
        (0..(day_time_vector.size - 1)).each do |i|
          set_sch_names << "#{set_sch_name}time #{i}"
          set_sch_values << day_value_vector[i].to_f
          target_value = day_value_vector[i] - adjust_value
          sch_day.addValue(day_time_vector[i], target_value)
        end
      end
    end

    case conditioning
    when 'cooling'
      @clg_set_sch_name = set_sch_names
      @clg_set_sch_value = set_sch_values
    when 'heating'
      @htg_set_sch_name = set_sch_names
      @htg_set_sch_value = set_sch_values
    end
    model.save(model_out.to_s, true)
  end
end
