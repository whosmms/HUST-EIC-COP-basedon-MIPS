# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "BUTTON_DEBOUNCE_CLKS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENEMY_MAX_LEN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENEMY_MIN_LEN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENEMY_SPAWN_MIN_TICKS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ENEMY_SPAWN_RANDOM_MASK" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TICK_DIV" -parent ${Page_0}


}

proc update_PARAM_VALUE.BUTTON_DEBOUNCE_CLKS { PARAM_VALUE.BUTTON_DEBOUNCE_CLKS } {
	# Procedure called to update BUTTON_DEBOUNCE_CLKS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BUTTON_DEBOUNCE_CLKS { PARAM_VALUE.BUTTON_DEBOUNCE_CLKS } {
	# Procedure called to validate BUTTON_DEBOUNCE_CLKS
	return true
}

proc update_PARAM_VALUE.ENEMY_MAX_LEN { PARAM_VALUE.ENEMY_MAX_LEN } {
	# Procedure called to update ENEMY_MAX_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENEMY_MAX_LEN { PARAM_VALUE.ENEMY_MAX_LEN } {
	# Procedure called to validate ENEMY_MAX_LEN
	return true
}

proc update_PARAM_VALUE.ENEMY_MIN_LEN { PARAM_VALUE.ENEMY_MIN_LEN } {
	# Procedure called to update ENEMY_MIN_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENEMY_MIN_LEN { PARAM_VALUE.ENEMY_MIN_LEN } {
	# Procedure called to validate ENEMY_MIN_LEN
	return true
}

proc update_PARAM_VALUE.ENEMY_SPAWN_MIN_TICKS { PARAM_VALUE.ENEMY_SPAWN_MIN_TICKS } {
	# Procedure called to update ENEMY_SPAWN_MIN_TICKS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENEMY_SPAWN_MIN_TICKS { PARAM_VALUE.ENEMY_SPAWN_MIN_TICKS } {
	# Procedure called to validate ENEMY_SPAWN_MIN_TICKS
	return true
}

proc update_PARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK { PARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK } {
	# Procedure called to update ENEMY_SPAWN_RANDOM_MASK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK { PARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK } {
	# Procedure called to validate ENEMY_SPAWN_RANDOM_MASK
	return true
}

proc update_PARAM_VALUE.TICK_DIV { PARAM_VALUE.TICK_DIV } {
	# Procedure called to update TICK_DIV when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TICK_DIV { PARAM_VALUE.TICK_DIV } {
	# Procedure called to validate TICK_DIV
	return true
}


proc update_MODELPARAM_VALUE.TICK_DIV { MODELPARAM_VALUE.TICK_DIV PARAM_VALUE.TICK_DIV } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TICK_DIV}] ${MODELPARAM_VALUE.TICK_DIV}
}

proc update_MODELPARAM_VALUE.BUTTON_DEBOUNCE_CLKS { MODELPARAM_VALUE.BUTTON_DEBOUNCE_CLKS PARAM_VALUE.BUTTON_DEBOUNCE_CLKS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BUTTON_DEBOUNCE_CLKS}] ${MODELPARAM_VALUE.BUTTON_DEBOUNCE_CLKS}
}

proc update_MODELPARAM_VALUE.ENEMY_SPAWN_MIN_TICKS { MODELPARAM_VALUE.ENEMY_SPAWN_MIN_TICKS PARAM_VALUE.ENEMY_SPAWN_MIN_TICKS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENEMY_SPAWN_MIN_TICKS}] ${MODELPARAM_VALUE.ENEMY_SPAWN_MIN_TICKS}
}

proc update_MODELPARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK { MODELPARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK PARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK}] ${MODELPARAM_VALUE.ENEMY_SPAWN_RANDOM_MASK}
}

proc update_MODELPARAM_VALUE.ENEMY_MIN_LEN { MODELPARAM_VALUE.ENEMY_MIN_LEN PARAM_VALUE.ENEMY_MIN_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENEMY_MIN_LEN}] ${MODELPARAM_VALUE.ENEMY_MIN_LEN}
}

proc update_MODELPARAM_VALUE.ENEMY_MAX_LEN { MODELPARAM_VALUE.ENEMY_MAX_LEN PARAM_VALUE.ENEMY_MAX_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENEMY_MAX_LEN}] ${MODELPARAM_VALUE.ENEMY_MAX_LEN}
}

