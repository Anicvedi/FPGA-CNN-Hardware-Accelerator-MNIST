# ================================
# Clean reproducible Vivado script
# ================================

set origin_dir "."
set proj_name "DSD_CNN_MNIST"

create_project $proj_name ./$proj_name -part xc7a200tfbg484-1

# ----------------
# Source files
# ----------------
add_files [glob ./src/design/*.v]
add_files [glob ./src/bram_init/*.coe]

# Constraints
add_files ./src/constraints/constraints.xdc

# Testbenches (optional)
add_files [glob ./src/testbenches/*.v]

# ----------------
# IP (from repo ip/)
# ----------------
read_ip ./ip/bram_activations.xci
read_ip ./ip/bram_weights.xci
read_ip ./ip/bram_instructions.xci

upgrade_ip [get_ips *]
generate_target all [get_ips *]

# ----------------
# Top module
# ----------------
set_property top accelerator_TOP [current_fileset]

# ----------------
# Runs
# ----------------
launch_runs synth_1
wait_on_run synth_1

# Optional:
# launch_runs impl_1
# wait_on_run impl_1

puts "INFO: Project recreated successfully"