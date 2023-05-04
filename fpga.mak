#################################
# FPGA Build
#################################

-include prj_def
-include rev_def

VIV_VER   = 2019.2
VIV_CMD   = `/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch`
SCR_DIR   = /home/<user>/scripts
#VIV_CMD   = `/opt/Xilinx/Vivado/$(VIV_VER)/settings64.sh;/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch`
NOW	  = $$(date +'%Y-%m-%d')
TIME	  = $$(date +'%H.%M')
XPR	  = `ls *.xpr`
XPR_BASE  = `$(XPR) | sed -r s/\.xpr//`
CORES     = `getcpu`
TCLSH	  =  /usr/bin/tclsh

XPR_REPORTS =
varp = printf "%-40s = $-s\n" $(1) $(2) >> prj_def

ROLL_REV_MAJOR := $$(expr $(REV_MAJOR) + 1)
ROLL_REV_MINOR := $$(expr $(REV_MINOR) + 1)
ROLL_REV_BUILD := $$(expr $(REV_BUILD) + 1)
DASH_REV := $$(printf '%02d_%02d_%02d' $(REV_MAJOR) $(REV_MINOR) $(REV_BUILD))
DOT_REV  := $$(printf '%02d.%02d.%02d' $(REV_MAJOR) $(REV_MINOR) $(REV_BUILD))
PRJ_REV := $(PROJ_$(DOT_REV)
LOG = "No log message entered"



.SILENT:
	@echo 'Run Silently. Comment out this section to see all commands'

default:
	@echo " "
	@echo "$(NOW) $(TIME)"
	@echo "ISE Tool chain"
	@echo "  make i_xst        --> synthesis"
	@echo "  make i_ngdbuild   --> ngdbuild"
	@echo "  make i_map        --> map"
	@echo "  make i_par        --> place and route"
	@echo "  make i_bitgen     --> Generate Bit File"
	@echo "  make i_prom       --> Create PROM"
	@echo "  make i_build_all  --> Run Xst to Bitstream"
	@echo "  make i_clean      --> Clean Project"
	@echo " "
	@echo "Vivado Tool Chain"
	@echo "  make v_synth       --> Synthesis Run (synth_1)"
	@echo "  make v_impl        --> Implentation Run (impl_1)"   
	@echo "  make v_gen_bitfile --> Generate Bitstream (impl_1)"
	@echo "  make v_gen_pinout  --> Generate pinout (synth_1)"
	@echo "  make v_build_all   --> Run Synth to Bitstream"
	@echo "  make v_clean       --> Clean Project Files"
	@echo "  make roll_build    --> Roll the build revision for the next build"
	@echo "  make roll_minor    --> Roll the minor revision for the next build"
	@echo "  make roll_major    --> Roll the major revision for the next build"
	@echo " "
	@echo "Project Functions"
	@echo "  make fpga_norev    LOG=\"<LOG>\" ---> Roll BUILD, build FPGA"
	@echo "  make fpga_build    LOG=\"<LOG>\" ---> Roll BUILD, build FPGA"
	@echo "  make fpga_minor    LOG=\"<LOG>\" ---> Roll MINOR, build FPGA"
	@echo "  make fpga_major    LOG=\"<LOG>\" ---> Roll MAJOR, build FPGA"
	@echo "  make create_project_dir  ---> Create Project Directories"
	@echo "  make create_project      ---> Create Project and Settings"
	@echo " "


nothing:
	@echo 'Nothing'

#################################
# ISE
#################################

i_clean:
	@echo '[.] Cleaning ISE project files'

i_build_all:
	@echo '[.] Building ISE FPGA'
	date; \
	make i_xst;
	make i_ngdbuild;
	make i_map;
	make i_par;
	make i_bitgen;

i_xst:
	@echo ' Running ISE Xst'
	cd syn; \
	pwd; \
	xst -ifn $(PROJECT).xst; \
#	mv xst_synthesis.ngc $(PROJECT).ngc; \
	cd ..;

i_ngbuild:
	@echo ' Running ISE NGDBuild'
	cd syn; \
	ngdbuild \
		-aul \
		-sd ../coregen \
		-dd ngo \
		-p $(PART_TYPE) \
		-uc ../syn/$(PROJECT).ucf \
			$(PROJECT).ngc \
			$(PROJECT).ngd; \
	cd ..;

i_map:
	@echo ' Running ISE Map'
	cd syn; \
	map \
		-p $(PART_TYPE) \
		-u \
		-cm area \
		-pr b \
		$(PROJECT).ngd; \
	cd ..;

i_par:
	@echo ' Running ISE PAR'
	cd syn; \
	par \
		-w \
		-ol high \
		-t 2 \
		$(PROJECT).ncd \
		$(PROJECT)_par; \
	cd ..;


i_bitgen:
	@echo ' Running ISE BITGEN'
	cd syn; \
	bitgen \
		-d -w -g startupclk:cclk \
		-g DriveDone:Yes \
		-g unusedpin:pullnone \
		-g userid:$(BITGEN_USERID) \
		-l -m \
		$(PROJECT)_par.ncd \
		$(PROJECT).bit; \
	cd ..;

#################################
# Vivado
#################################

v_create_prj_dir:
	@echo "[.] Creating Project Directories"
	tclsh $(SCR_DIR)/create_prj_dir.tcl;
#	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -source $(SCR_DIR)/create_project_dir.tcl;


v_create_prj_cmd:
	@echo "[.] Creating Project Script"
	@echo "open_project $(XPR)" > prj.tcl
	@echo "set_param general.MaxThreads $(CORES)" >> prj.tcl
	@echo "update_compile_order –fileset sources_1" >> prj.tcl

v_create_new_prj:
	@echo '[.] Creating New Project'
	@echo '[.] Vivado Version : $(VIV_VER)'
	make -f $(SCR_DIR)/fpga.mak v_create_prj_dir
	make -f $(SCR_DIR)/fpga.mak v_create_prj
#	make -f $(SCR_DIR)/fpga.mak v_create_prj_cmd
	
v_create_prj:
	@echo "[.] Creating Project"
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source $(SCR_DIR)/create_project.tcl;

v_add_src:
	@echo "[.] Adding sources from sources/hdl to project"
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source $(SCR_DIR)/add_src.tcl;
	

v_resetruns:
	@echo '[.] Resetting Project Runs'
	@echo '[.] Vivado Version : $(VIV_VER)'
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source prj.tcl -source $(SCR_DIR)/reset_runs.tcl;

v_synth:
	@echo '[.] Running Vivado Synthesis'
	@echo '[.] Vivado Version : $(VIV_VER)'
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source prj.tcl -source $(SCR_DIR)/run_synth.tcl;

v_impl:
	@echo '[.] Running Vivado Implmentation'
	@echo '[.] Vivado Version : $(VIV_VER)'
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source prj.tcl -source $(SCR_DIR)/run_impl.tcl;

v_gen_bitfile:
	@echo '[.] Running Vivado Bit Stream Generation'
	@echo '[.] Vivado Version : $(VIV_VER)'
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source prj.tcl -source $(SCR_DIR)/gen_bitfile.tcl;

	
v_gen_pinout:
	@echo '[.] Running Vivado Bit Stream Generation'
	@echo '[.] Vivado Version : $(VIV_VER)'
	/opt/Xilinx/Vivado/$(VIV_VER)/bin/vivado -mode batch -notrace -source prj.tcl -source $(SCR_DIR)/gen_pinout.tcl;

v_build_all:
	@echo '[.] Running Vivado Synthesis to Bit Stream'
	make -f $(SCR_DIR)/fpga.mak v_resetruns
	make -f $(SCR_DIR)/fpga.mak v_synth
	make -f $(SCR_DIR)/fpga.mak v_impl
	make -f $(SCR_DIR)/fpga.mak v_gen_bitfile

	@echo ""
	@echo "[.] *****************************************************"
	@echo "[.] Synthesis Errors"
	@echo "[.] *****************************************************"
	grep Errors ./*.runs/synth_1/runme.log

	@echo "[.] *****************************************************"
	@echo "[.] Implementation Errors"
	@echo "[.] *****************************************************"
	grep Errors ./*.runs/impl_1/runme.log
	@echo "[.] *****************************************************"

	@echo "[.] *****************************"
	@echo "[.] Build All Tasks Completed"
	@echo "[.] *****************************"

v_clean:
	@echo ' Cleaning logs, journal,and str files'
	rm -rf ./*.log
	rm -rf ./*.jou
	rm -rf ./*.str

	@echo ""
	@echo "[.] *****************************"
	@echo "[.] Task Completed"
	@echo "[.] *****************************"

v_backup:
	@echo "********************************"
	@echo " Backing up design "
	@echo "   Work only, not tb or release"
	@echo "********************************"
	@echo "Cleaning files"
	make -f $(SCR_DIR)/fpga.mak v_clean

	@echo "Archiving files : Time depends on size of directory"    
#	tar czf $(DIR_BACKUP)/$(PCBNUM)_$(PCBREV)-$(TSTAMP).tgz $(DIR_WORK)
	@echo "Archive Created"
#	@echo "file location: $(DIR_BACKUP)/$(PCBNUM)_$(PCBREV)-$(TSTAMP).tgz"
	@echo ""
	@echo "*****************************"
	@echo "Task Completed"
	@echo "*****************************"

fpga_norev: 
	@echo ""
	@echo ""
	@echo "********************************************"
	@echo "         Building Complete FPGA             "
	@echo "********************************************"
	printf "REV_MAJOR = %02d\n" $(REV_MAJOR)
	printf "REV_MINOR = %02d\n" $(REV_MINOR)
	printf "REV_BUILD = %02d\n" $(REV_BUILD)
	printf "DASH_REV  = %s\n" $(DASH_REV)
	printf "DOT_REV   = %s\n" $(DOT_REV)
	printf "PRJ_REV   = %s\n" $(PRJ_REV)
	printf "LOG       = " && printf "%s " $(LOG) && printf "\n"
	date

	@echo '[.] Running Vivado Synthesis to Bit Stream'
	make -f $(SCR_DIR)/fpga.mak v_resetruns
	make -f $(SCR_DIR)/fpga.mak v_synth
	make -f $(SCR_DIR)/fpga.mak v_impl
	make -f $(SCR_DIR)/fpga.mak v_gen_bitfile

	@echo ""
	@echo "[.] *****************************************************"
	@echo "[.] Synthesis Errors"
	@echo "[.] *****************************************************"
	grep Errors ./*.runs/synth_1/runme.log

	@echo "[.] *****************************************************"
	@echo "[.] Implementation Errors"
	@echo "[.] *****************************************************"
	grep Errors ./*.runs/impl_1/runme.log
	@echo "[.] *****************************************************"

	@echo "[.] *****************************"
	@echo "[.] Build All Tasks Completed"
	@echo "[.] *****************************"
	@echo " "
	@echo " "
	@echo " "
	@echo " "
	@echo " "
	@echo "[.] Built Project : $(PRJ)_$(DOT_REV)"
	@echo " "
	@echo " "
	@echo " "
	@echo " "
	@echo " "

fpga:
	make -f $(SCR_DIR)/fpga.mak fpga_build

fpga_build:
	make -f $(SCR_DIR)/fpga.mak roll_build
	make -f $(SCR_DIR)/fpga.mak fpga_norev

fpga_minor:
	make -f $(SCR_DIR)/fpga.mak roll_minor
	make -f $(SCR_DIR)/fpga.mak fpga_norev

fpga_major:
	make -f $(SCR_DIR)/fpga.mak roll_major
	make -f $(SCR_DIR)/fpga.mak fpga_norev

RUN_CMD:
	@echo " "
	@echo " "
	@echo "*****************************************"
	@echo "  Running Command : $(CMDTITLE)"
	@echo "*****************************************"
	echo "$(NOW) : $(CMD)" >> $(PRJ).rev
	# put command here eg: cd $(SYN_DIR) && $(CMD)
	echo "$(NOW) :      Completed Successfully " >> $(PRJ.rev

roll_build:
	@echo "REV_MAJOR := $(REV_MAJOR)" > rev_def
	@echo "REV_MINOR := $(REV_MINOR)" >> rev_def
	@echo "REV_BUILD := $(ROLL_REV_BUILD)" >> rev_def

	@echo "\`timescale 1ns / 1ps" > $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "module RevCtrlModule () ; " >> $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "parameter REV_MAJOR = $(REV_MAJOR);  " >> $(REV_FILE)
	@echo "parameter REV_MMINOR = $(REV_MINOR);  " >> $(REV_FILE)
	@echo "parameter REV_BUILD = $(ROLL_REV_BUILD);  " >> $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "endmodule" >> $(REV_FILE)


roll_minor:
	@echo "REV_MAJOR := $(REV_MAJOR)" > rev_def
	@echo "REV_MINOR := $(ROLL_REV_MINOR)" >> rev_def
	@echo "REV_BUILD := 0" >> rev_def

	@echo "\`timescale 1ns / 1ps" > $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "module RevCtrlModule () ; " >> $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "parameter REV_MAJOR = $(REV_MAJOR);  " >> $(REV_FILE)
	@echo "parameter REV_MINOR = $(ROLL_REV_MINOR);  " >> $(REV_FILE)
	@echo "parameter REV_BUILD = 0;  " >> $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "endmodule" >> $(REV_FILE)


roll_major:
	@echo "REV_MAJOR := $(REV_MAJOR)" > rev_def
	@echo "REV_MINOR := 0" >> rev_def
	@echo "REV_BUILD := 0" >> rev_def

	@echo "\`timescale 1ns / 1ps" > $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "module RevCtrlModule () ; " >> $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "parameter REV_MAJOR = $(ROLL_REV_MAJOR);  " >> $(REV_FILE)
	@echo "parameter REV_MINOR = 0;  " >> $(REV_FILE)
	@echo "parameter REV_BUILD = 0;  " >> $(REV_FILE)
	@echo " " >> $(REV_FILE)
	@echo "endmodule" >> $(REV_FILE)




prj_def:
	touch prj_def

rev_def:
	touch rev_def	



