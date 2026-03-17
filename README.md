# DSD_MNIST_Systolic
Sysyolic array based CNN accelerator for MNIST digit recognition on FPGA

Folder structure:

root
|   .gitignore
|   README.md
|
+---CNN_development
|       .gitkeep
|
+---docs
|       Block_diagram.png
|       Block_diagrams.pptx
|       DSD_CourseProject_Proposal.pdf
|
+---src
|   +---bram_init
|   |       .gitkeep
|   |
|   +---constraints
|   |       .gitkeep
|   |
|   +---design
|   |       .gitkeep
|   |       bram_activations.v
|   |       bram_instruction.v
|   |       bram_weights.v
|   |       controller.v
|   |       ops_classify.v
|   |       ops_convrelu.v
|   |       ops_convrelu_PEArray.v
|   |       ops_maxpool.v
|   |       serial_to_bram.v
|   |       top.v
|   |
|   \---testbenches
|           .gitkeep
|
\---vivado_project_dir
        .gitkeep