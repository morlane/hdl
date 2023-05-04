puts "----------------------------"
puts "   Building of Design"
puts "----------------------------"

set jobs 24
set project <project>.xpr
set synth synth_1
set impl impl_1
set device xcku3p-ffva676-1-e
set fn_ft flighttime
set output_dir ./reports
set scripts /home/<user>/scripts

file mkdir $output_dir

puts " Opening Project : $project"
open_project $project

puts " Reset runs  : $synth"
reset_runs $synth

puts " Launching Synthesis"
launch_runs $synth -jobs $jobs
wait_on_run $synth

#puts " Using Device : $device"
#link_design -part $device
puts " Opening Run : $synth"
open_run $synth

puts " Writing Flight Times : $fn_ft"
write_csv -force $output_dir/$fn_ft

puts " Closing Design"
close_design 

puts " Setting Properties"
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.PRE [pwd]/pre_opt_design.tcl [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.POST [pwd]/post_opt_design.tcl [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.TCL.POST [pwd]/post_place_design.tcl [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.TCL.POST [pwd]/post_phys_opt_design.tcl [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.POST [pwd]/post_route_design.tcl [get_runs impl_1]

puts "Launching Implementation"
launch_runs $impl -to_step write_bitstream -jobs $jobs
wait_on_run $impl

puts " Closing Project "
close_project $project

