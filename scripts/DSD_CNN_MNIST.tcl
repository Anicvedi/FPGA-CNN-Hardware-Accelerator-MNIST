# ================================
# Clean reproducible Vivado script
# ================================

# [info script]             → …/scripts/DSD_CNN_MNIST.tcl
# [file dirname …]          → …/scripts/
# [file join … ".."]        → …/              ← project root
set origin_dir [file normalize [file join [file dirname [info script]] ".."]]

# --------------------------------------------------------
# Project name
#   Option 1 — edit the default value below, run normally
#
#   Option 2 — batch mode (no file edit needed):
#     vivado -mode batch -source scripts/DSD_CNN_MNIST.tcl -tclargs MyProjectName
#
#   Option 3 — Vivado Tcl console / GUI (set argv BEFORE sourcing):
#     set argv [list MyProjectName]
#     source .../scripts/DSD_CNN_MNIST.tcl
#     NOTE: `source script.tcl MyProjectName` is NOT valid in the Tcl console
# --------------------------------------------------------
if { [llength $argv] > 0 } {
    set proj_name [lindex $argv 0]
    puts "INFO: Project name overridden via -tclargs: $proj_name"
} else {
    set proj_name "DSD_CNN_MNIST"
}

# Project folder created at <project_root>/$proj_name/
create_project $proj_name $origin_dir/$proj_name -part xc7a200tfbg484-1

# --------------------------------------------------------
# Source files  →  sources_1 (synthesis + implementation)
# --------------------------------------------------------
add_files -norecurse [glob $origin_dir/src/design/*.v]

# NOTE: .coe files are BRAM initialisation files consumed by IP cores
#       via their .xci configuration.  They must NOT be added here as
#       standalone source files — Vivado has no defined source type for
#       them and will either error or silently ignore them.  The .xci
#       files read below already reference the correct .coe paths.

# --------------------------------------------------------
# Constraints  →  constrs_1  (NOT sources_1)
# --------------------------------------------------------
add_files -fileset constrs_1 -norecurse \
    $origin_dir/src/constraints/constraints.xdc

# --------------------------------------------------------
# Simulation fileset: top_level_uart
#
# Replaces the default sim_1.  Contains the testbench HDL and all data
# files (test vectors, BRAM init hex, model weights) needed by xsim.
# Vivado copies every file in the fileset into each xsim working
# directory at compile time, so $readmemh uses bare filenames.
# --------------------------------------------------------
create_fileset -simset top_level_uart

# Testbench HDL — only tb_accelerator_top.v, not all testbenches
add_files -fileset top_level_uart -norecurse \
    $origin_dir/src/testbenches/tb_accelerator_top.v

# Data files — two source directories:
#   modelTtraining_.../                : single-image outputs + BRAM hex + model
#   modelTtraining_.../test_images_uart/  : multi-image test vectors
set model_dir    [file join $origin_dir CNN_development \
    modelTtraining_memInitFilesGen_testVectorsGen]
set sim_data_dir [file join $model_dir test_images_uart]

# { filename  directory }
foreach pair {
    {best_model.pth             model_dir}
    {bram_instructions_init.hex model_dir}
    {bram_weights_init.hex      model_dir}
    {expected_class.hex         model_dir}
    {test_image_uart_bytes.hex  model_dir}
    {all_uart_bytes.hex         sim_data_dir}
    {expected_classes.hex       sim_data_dir}
    {test_config.hex            sim_data_dir}
    {true_labels.hex            sim_data_dir}
} {
    set f   [lindex $pair 0]
    set dir [lindex $pair 1]

    if { $dir eq "model_dir" } {
        set fpath [file join $model_dir $f]
    } else {
        set fpath [file join $sim_data_dir $f]
    }

    if { [file exists $fpath] } {
        add_files -fileset top_level_uart -norecurse $fpath
        puts "INFO: Added sim data file: $f"
    } else {
        puts "WARNING: Sim data file not found, skipping: $fpath"
    }
}

# --------------------------------------------------------
# IP cores
#
# Each .xci embeds a COE_FILE path relative to its original project.
# Vivado validates COE_FILE *during* import_ip — if the path is broken
# the import fails and locks the IP, so set_property afterwards is not
# possible. The path must be correct before import_ip sees the XCI.
#
# Fix: patch the COE path to absolute in-memory, write to a temp file
# in %TEMP% keeping the original basename (import_ip requires the
# filename sans .xci to match the instance name inside the XML), import,
# then delete the temp file. The original .xci is never modified.
# --------------------------------------------------------
proc import_ip_abs_coe { xci_src coe_dir } {
    set ip_name [file rootname [file tail $xci_src]]

    set fh [open $xci_src r]
    set xml [read $fh]
    close $fh

    if { [regexp {([^/"\\<>]+\.coe)} $xml _ coe_fname] } {
        set abs_coe [string map {\\ /} \
            [file normalize [file join $coe_dir $coe_fname]]]
        regsub -all {[^"<>\s]*\.coe} $xml $abs_coe xml
        puts "INFO: Patched COE path for $ip_name -> $abs_coe"
    } else {
        puts "WARNING: No .coe reference found in [file tail $xci_src]"
    }

    # Write to %TEMP% with the original filename — import_ip requires the
    # basename (sans .xci) to match the instance name declared in the XML.
    set tmp [file join [file normalize $::env(TEMP)] [file tail $xci_src]]
    set fh [open $tmp w]
    puts -nonewline $fh $xml
    close $fh

    import_ip -name $ip_name $tmp
    file delete $tmp
}

set coe_dir [file join $origin_dir src bram_init]
import_ip_abs_coe [file join $origin_dir ip bram_activations.xci]  $coe_dir
import_ip_abs_coe [file join $origin_dir ip bram_weights.xci]      $coe_dir
import_ip_abs_coe [file join $origin_dir ip bram_instructions.xci] $coe_dir

upgrade_ip [get_ips *]
generate_target all [get_ips *]
export_ip_user_files -of_objects [get_ips *] -no_script -sync -force -quiet

# --------------------------------------------------------
# Top-level module assignments
# --------------------------------------------------------
# Synthesis / implementation top
set_property top accelerator_TOP [get_filesets sources_1]

# Simulation top and active fileset
set_property top tb_accelerator_TOP [get_filesets top_level_uart]
current_fileset -simset [get_filesets top_level_uart]

# --------------------------------------------------------
# Runs
# --------------------------------------------------------
launch_runs synth_1
wait_on_run synth_1

# Uncomment when ready to run implementation + bitstream:
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

puts "INFO: Project $proj_name recreated successfully"