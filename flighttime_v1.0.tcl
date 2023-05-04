puts "----------------------------"
puts "    Getting flight times"
puts "----------------------------"

set synth synth_1
set device xcku3p-ffva676-1-e
set fn flighttime

puts " Opening Run  : $synth"
open_run synth_1

#puts " Using Device : $device"
#link_design -part $device

puts " Writing File : $fn"
write_csv -force $fn

puts " Flight times generated"


