# DSD_MNIST_Systolic
Sysyolic array based CNN accelerator for MNIST digit recognition on FPGA

Folder structure:
```text
root
│   .gitignore
│   README.md
│
├───CNN_development
│   │   .gitkeep
│   │   CNN_for_MNIST.ipynb
│   │
│   └───modelTtraining_memInitFilesGen_testVectorsGen
│       │   best_model.pth
│       │   bram_instructions_init.coe
│       │   bram_instructions_init.hex
│       │   bram_weights_init.coe
│       │   bram_weights_init.hex
│       │   expected_class.hex
│       │   ground_truth_summary.txt
│       │   model_weights.txt
│       │   test_image_uart_bytes.hex
│       │   train_and_gen_model_init_files_V5.py
│       │
│       ├───data
│       │   └───MNIST
│       │       └───raw          ← MNIST dataset (auto-downloaded)
│       │
│       └───test_images_uart
│               all_uart_bytes.hex
│               expected_classes.hex
│               manifest.txt
│               test_config.hex
│               true_labels.hex
│
├───docs
│       Block_diagram.png
│       Block_diagrams.pptx
│       DSD_CourseProject_Proposal.pdf
│
├───ip
│       bram_activations.xci
│       bram_instructions.xci
│       bram_weights.xci
│
├───scripts
│       DSD_CNN_MNIST.tcl
│
├───src
│   ├───bram_init
│   │       bram_activation_init.coe
│   │       bram_instructions_init.coe
│   │       bram_weights_init.coe
│   │
│   ├───constraints
│   │       constraints.xdc
│   │
│   ├───design
│   │       bram_activations_wrapper.v
│   │       bram_instructions_wrapper.v
│   │       bram_weights_wrapper.v
│   │       controller.v
│   │       ops_classifier.v
│   │       ops_convrelu.v
│   │       ops_maxpool.v
│   │       seg7_driver.v
│   │       serial_to_bram.v
│   │       top.v
│   │
│   └───testbenches
│           tb_accelerator_top.v
│           tb_system_integration_full_CNN.v
│           tb_system_integration_full_CNN_MNIST_Data.v
│           tb_controller_convMaxp.v
│           tb_system_integration_conv_and_maxpool.v
│           tb_only_convrelu.v
│           tb_controller_maxp_V3.v
│           tb_ops_maxpool.v
│           tb_controller_V2.v
```

---

## Replicating This Project

1. Create an empty folder. It will be referred to as `repository_dir`.

2. Clone the repository:
   ```
   git clone https://github.com/prayanshus/DSD_MNIST_Systolic.git
   ```

3. Navigate into the repo:
   ```
   cd DSD_MNIST_Systolic
   ```

4. Check out the target branch:
   ```
   git checkout process/synthesis
   ```

5. Launch Vivado and open the Tcl Console (**Tools → Tcl Console**).

6. In the Tcl Console, set the working directory:
   ```tcl
   cd <repository_dir>/DSD_MNIST_Systolic/
   ```

7. Set a custom project name (optional — omit to use the default `DSD_CNN_MNIST`):
   ```tcl
   set argv [list <your_custom_project_name>]
   ```

8. Source the project generation script:
   ```tcl
   source <repository_dir>/DSD_MNIST_Systolic/scripts/DSD_CNN_MNIST.tcl
   ```

9. Once the script completes, **run the behavioural simulation once to verify project status.**
