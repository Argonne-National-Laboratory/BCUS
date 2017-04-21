# Copyright © 2016 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.  Software changes,
#    modifications, or derivative works, should be noted with comments and the
#    author and organization’s name.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor
#    the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# 4. The software and the end-user documentation included with the
#    redistribution, if any, must include the following acknowledgment:
#
#    "This product includes software produced by UChicago Argonne, LLC under
#     Contract No. DE-AC02-06CH11357 with the Department of Energy.”
#
# *****************************************************************************
# DISCLAIMER
#
# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.
#
# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
#
# *****************************************************************************

# Modified Date and By:
# - Created on July 2016 by Yuna Zhang from Argonne National Laboratory
# - 01-apr-2017: Refactored to better match ruby coding standards by RTM
# 21-Apr-2017 RTM ran through rubocop linter for code cleanup

# 1. Introduction
# This is the subfunction called by Uncertain_Parameters to set uncertainty for
#  thermostat
# Thermostat dual setpoint uncertainty works for SI unit only

# 2. Call structure
# Refer to 'Function Call Structure_UA.pptx'
class ThermostatUncertainty < OpenStudio::Model::Model
  attr_reader :clg_set_schs_name
  attr_reader :htg_set_schs_name
  attr_reader :clg_sch_set_values
  attr_reader :htg_sch_set_values

  def initialize
    @clg_set_schs_name = []
    @clg_sch_set_values = []
    @htg_set_schs_name = []
    @htg_sch_set_values = []
  end

  def cooling_method(model, adjust_value_cooling, model_output_path)
    # push schedules to hash to avoid making unnecessary duplicates
    clg_set_schs = {}

    # get thermostats and setpoint schedules
    thermostats = model.getThermostatSetpointDualSetpoints
    thermostats.each do |thermostat|
      # setup new cooling setpoint schedule
      clg_set_sch = thermostat.coolingSetpointTemperatureSchedule
      next if clg_set_sch.empty?
      # clone of not alredy in hash
      if clg_set_schs.key?(clg_set_sch.get.name.to_s)
        new_clg_set_sch = clg_set_schs[clg_set_sch.get.name.to_s]
      else
        new_clg_set_sch = clg_set_sch.get.clone(model)
        new_clg_set_sch = new_clg_set_sch.to_Schedule.get
        new_clg_set_sch_name = new_clg_set_sch.setName("#{new_clg_set_sch.name} adjusted")
        # add to the hash
        clg_set_schs[clg_set_sch.get.name.to_s] = new_clg_set_sch
      end
      # hook up clone to thermostat
      thermostat.setCoolingSetpointTemperatureSchedule(new_clg_set_sch)
      # end unless clg_set_sch.empty?
    end
    clg_set_schs.each do |_k, v| # old name and new object for schedule
      clg_set_schedules_name = v.name.to_s

      next if v.to_ScheduleRuleset.empty?
      # array to store profiles inules.each do |rule|
      profiles = []
      schedule = v.to_ScheduleRuleset.get
      # push default profiles to array
      default_rule = schedule.defaultDaySchedule
      profiles << default_rule
      # push profiles to array
      rules = schedule.scheduleRules
      rules.each do |rule|
        day_sch = rule.daySchedule
        profiles << day_sch
      end

      profiles.each do |sch_day|
        day_time_vector = sch_day.times
        day_value_vector = sch_day.values
        for i in 0..(day_time_vector.size - 1)
          @clg_set_schs_name << "#{clg_set_schedules_name}time #{i}"
          @clg_sch_set_values << day_value_vector[i].to_f
          target_value = day_value_vector[i] - adjust_value_cooling
          sch_day.addValue(day_time_vector[i], target_value)
        end
      end # end of profiles.each do

      # end of unless
    end # end clg_set_schs.each do
    model.save(model_output_path.to_s, true)
  end

  def heating_method(model, adjust_value_heating, model_output_path)
    htg_set_schs = {}
    thermostats = model.getThermostatSetpointDualSetpoints
    thermostats.each do |thermostat|
      # setup new heating setpoint schedule
      htg_set_sch = thermostat.heatingSetpointTemperatureSchedule
      next if htg_set_sch.empty?
      # clone of not alredy in hash
      if htg_set_schs.key?(htg_set_sch.get.name.to_s)
        new_htg_set_sch = htg_set_schs[htg_set_sch.get.name.to_s]
      else
        new_htg_set_sch = htg_set_sch.get.clone(model)
        new_htg_set_sch = new_htg_set_sch.to_Schedule.get
        new_htg_set_sch_name = new_htg_set_sch.setName("#{new_htg_set_sch.name} adjusted")

        # add to the hash
        htg_set_schs[htg_set_sch.get.name.to_s] = new_htg_set_sch
      end
      # hook up clone to thermostat
      thermostat.setHeatingSetpointTemperatureSchedule(new_htg_set_sch)
      # end if not htg_set_sch.empty?
    end

    htg_set_schs.each do |_k, v| # old name and new object for schedule
      htg_set_schedules_name = v.name.to_s
      next if v.to_ScheduleRuleset.empty?
      profiles_1 = []
      schedule = v.to_ScheduleRuleset.get
      # push default profiles to array
      default_rule = schedule.defaultDaySchedule
      profiles_1 << default_rule
      # push profiles to array
      rules = schedule.scheduleRules
      rules.each do |rule|
        day_sch = rule.daySchedule
        profiles_1 << day_sch
      end

      profiles_1.each do |sch_day|
        day_time_vector = sch_day.times
        day_value_vector = sch_day.values
        for i in 0..(day_time_vector.size - 1)
          @htg_set_schs_name << "#{htg_set_schedules_name}time #{i}"
          @htg_sch_set_values << day_value_vector[i].to_f
          target_value = day_value_vector[i] + adjust_value_heating
          sch_day.addValue(day_time_vector[i], target_value)
        end
      end
      # end of unless v.to_ScheduleRuleset.empty?
    end # end htg_set_schs.each do
    model.save(model_output_path.to_s, true)
  end
end
