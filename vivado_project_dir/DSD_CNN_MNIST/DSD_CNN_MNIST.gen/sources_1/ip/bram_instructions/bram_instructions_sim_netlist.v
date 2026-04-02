// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Thu Apr  2 07:28:16 2026
// Host        : PSL5 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               d:/00_IISc_Work/Sem2/DSD/CourseProject/working_dir/DSD_MNIST_Systolic/vivado_project_dir/DSD_CNN_MNIST/DSD_CNN_MNIST.gen/sources_1/ip/bram_instructions/bram_instructions_sim_netlist.v
// Design      : bram_instructions
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a200tfbg484-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "bram_instructions,blk_mem_gen_v8_4_12,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_12,Vivado 2025.2" *) 
(* NotValidForBitStream *)
module bram_instructions
   (clka,
    ena,
    wea,
    addra,
    dina,
    douta);
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *) (* x_interface_mode = "slave BRAM_PORTA" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTA, MEM_ADDRESS_MODE BYTE_ADDRESS, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER, READ_LATENCY 1" *) input clka;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA EN" *) input ena;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *) input [0:0]wea;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *) input [9:0]addra;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *) input [63:0]dina;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [63:0]douta;

  wire [9:0]addra;
  wire clka;
  wire [63:0]dina;
  wire [63:0]douta;
  wire ena;
  wire [0:0]wea;
  wire NLW_U0_dbiterr_UNCONNECTED;
  wire NLW_U0_rsta_busy_UNCONNECTED;
  wire NLW_U0_rstb_busy_UNCONNECTED;
  wire NLW_U0_s_axi_arready_UNCONNECTED;
  wire NLW_U0_s_axi_awready_UNCONNECTED;
  wire NLW_U0_s_axi_bvalid_UNCONNECTED;
  wire NLW_U0_s_axi_dbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_rlast_UNCONNECTED;
  wire NLW_U0_s_axi_rvalid_UNCONNECTED;
  wire NLW_U0_s_axi_sbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_wready_UNCONNECTED;
  wire NLW_U0_sbiterr_UNCONNECTED;
  wire [63:0]NLW_U0_doutb_UNCONNECTED;
  wire [9:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [9:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [63:0]NLW_U0_s_axi_rdata_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_rid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_rresp_UNCONNECTED;

  (* C_ADDRA_WIDTH = "10" *) 
  (* C_ADDRB_WIDTH = "10" *) 
  (* C_ALGORITHM = "1" *) 
  (* C_AXI_ID_WIDTH = "4" *) 
  (* C_AXI_SLAVE_TYPE = "0" *) 
  (* C_AXI_TYPE = "1" *) 
  (* C_BYTE_SIZE = "9" *) 
  (* C_COMMON_CLK = "0" *) 
  (* C_COUNT_18K_BRAM = "0" *) 
  (* C_COUNT_36K_BRAM = "2" *) 
  (* C_CTRL_ECC_ALGO = "NONE" *) 
  (* C_DEFAULT_DATA = "0" *) 
  (* C_DISABLE_WARN_BHV_COLL = "0" *) 
  (* C_DISABLE_WARN_BHV_RANGE = "0" *) 
  (* C_ELABORATION_DIR = "./" *) 
  (* C_ENABLE_32BIT_ADDRESS = "0" *) 
  (* C_EN_DEEPSLEEP_PIN = "0" *) 
  (* C_EN_ECC_PIPE = "0" *) 
  (* C_EN_RDADDRA_CHG = "0" *) 
  (* C_EN_RDADDRB_CHG = "0" *) 
  (* C_EN_SAFETY_CKT = "0" *) 
  (* C_EN_SHUTDOWN_PIN = "0" *) 
  (* C_EN_SLEEP_PIN = "0" *) 
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     5.9043 mW" *) 
  (* C_FAMILY = "artix7" *) 
  (* C_HAS_AXI_ID = "0" *) 
  (* C_HAS_ENA = "1" *) 
  (* C_HAS_ENB = "0" *) 
  (* C_HAS_INJECTERR = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_A = "1" *) 
  (* C_HAS_MEM_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_REGCEA = "0" *) 
  (* C_HAS_REGCEB = "0" *) 
  (* C_HAS_RSTA = "0" *) 
  (* C_HAS_RSTB = "0" *) 
  (* C_HAS_SOFTECC_INPUT_REGS_A = "0" *) 
  (* C_HAS_SOFTECC_OUTPUT_REGS_B = "0" *) 
  (* C_INITA_VAL = "0" *) 
  (* C_INITB_VAL = "0" *) 
  (* C_INIT_FILE = "bram_instructions.mem" *) 
  (* C_INIT_FILE_NAME = "bram_instructions.mif" *) 
  (* C_INTERFACE_TYPE = "0" *) 
  (* C_LOAD_INIT_FILE = "1" *) 
  (* C_MEM_TYPE = "0" *) 
  (* C_MUX_PIPELINE_STAGES = "0" *) 
  (* C_PRIM_TYPE = "1" *) 
  (* C_READ_DEPTH_A = "600" *) 
  (* C_READ_DEPTH_B = "600" *) 
  (* C_READ_LATENCY_A = "1" *) 
  (* C_READ_LATENCY_B = "1" *) 
  (* C_READ_WIDTH_A = "64" *) 
  (* C_READ_WIDTH_B = "64" *) 
  (* C_RSTRAM_A = "0" *) 
  (* C_RSTRAM_B = "0" *) 
  (* C_RST_PRIORITY_A = "CE" *) 
  (* C_RST_PRIORITY_B = "CE" *) 
  (* C_SIM_COLLISION_CHECK = "ALL" *) 
  (* C_USE_BRAM_BLOCK = "0" *) 
  (* C_USE_BYTE_WEA = "0" *) 
  (* C_USE_BYTE_WEB = "0" *) 
  (* C_USE_DEFAULT_DATA = "0" *) 
  (* C_USE_ECC = "0" *) 
  (* C_USE_SOFTECC = "0" *) 
  (* C_USE_URAM = "0" *) 
  (* C_WEA_WIDTH = "1" *) 
  (* C_WEB_WIDTH = "1" *) 
  (* C_WRITE_DEPTH_A = "600" *) 
  (* C_WRITE_DEPTH_B = "600" *) 
  (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
  (* C_WRITE_MODE_B = "WRITE_FIRST" *) 
  (* C_WRITE_WIDTH_A = "64" *) 
  (* C_WRITE_WIDTH_B = "64" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  (* is_du_within_envelope = "true" *) 
  bram_instructions_blk_mem_gen_v8_4_12 U0
       (.addra(addra),
        .addrb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .clka(clka),
        .clkb(1'b0),
        .dbiterr(NLW_U0_dbiterr_UNCONNECTED),
        .deepsleep(1'b0),
        .dina(dina),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(NLW_U0_doutb_UNCONNECTED[63:0]),
        .eccpipece(1'b0),
        .ena(ena),
        .enb(1'b0),
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .rdaddrecc(NLW_U0_rdaddrecc_UNCONNECTED[9:0]),
        .regcea(1'b1),
        .regceb(1'b1),
        .rsta(1'b0),
        .rsta_busy(NLW_U0_rsta_busy_UNCONNECTED),
        .rstb(1'b0),
        .rstb_busy(NLW_U0_rstb_busy_UNCONNECTED),
        .s_aclk(1'b0),
        .s_aresetn(1'b0),
        .s_axi_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arburst({1'b0,1'b0}),
        .s_axi_arid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arready(NLW_U0_s_axi_arready_UNCONNECTED),
        .s_axi_arsize({1'b0,1'b0,1'b0}),
        .s_axi_arvalid(1'b0),
        .s_axi_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awburst({1'b0,1'b0}),
        .s_axi_awid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awready(NLW_U0_s_axi_awready_UNCONNECTED),
        .s_axi_awsize({1'b0,1'b0,1'b0}),
        .s_axi_awvalid(1'b0),
        .s_axi_bid(NLW_U0_s_axi_bid_UNCONNECTED[3:0]),
        .s_axi_bready(1'b0),
        .s_axi_bresp(NLW_U0_s_axi_bresp_UNCONNECTED[1:0]),
        .s_axi_bvalid(NLW_U0_s_axi_bvalid_UNCONNECTED),
        .s_axi_dbiterr(NLW_U0_s_axi_dbiterr_UNCONNECTED),
        .s_axi_injectdbiterr(1'b0),
        .s_axi_injectsbiterr(1'b0),
        .s_axi_rdaddrecc(NLW_U0_s_axi_rdaddrecc_UNCONNECTED[9:0]),
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[63:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wlast(1'b0),
        .s_axi_wready(NLW_U0_s_axi_wready_UNCONNECTED),
        .s_axi_wstrb(1'b0),
        .s_axi_wvalid(1'b0),
        .sbiterr(NLW_U0_sbiterr_UNCONNECTED),
        .shutdown(1'b0),
        .sleep(1'b0),
        .wea(wea),
        .web(1'b0));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2025.2"
`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
YqH9kwIC39+qbZg4PSfFsXuB9k9wnuxNryS/CfnEri6Ci9fSC6fsrQ/T/hnt3u/yolbJ8DJa1Qu6
Qnm24A9jLbA+fu3Nsmm6/rM6a4vU6OfVl/gTFd/CiWDutv6Dhn6Lim4uUNPahoOR/A2Yc4Zo2tdI
kMLO9gn9WlH2l3O2oXs=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
XJYO2VHd/cnMxQd3i7/2qRhl57dl+doEKuhAunQyv3vpGRG/jlNxj8PqrgLoF0HMdqE3qJUVE/oq
kBSapqjVjLDMOrNGQ+Tc6VGsKMZH8FE/TXHQJ/IM5Iuiu2eozEwwVUomF+7cfqn+9OsVsqCONQ1M
g0oRlangiqasJDhhMfnlGGqwAwmgWRGQA6dmhTuua1s8zdvIv540zY6p5au8cAKVhqyyKK7wbxEE
SGuFqX+NYoyRV+rfWCcWM+hJEmnWS8LNAKkd13YE2+17sPYzUdZ23DmTxXK6KlAxKFW27CBySUfg
qdNXp2DSs2KAQYih27pBNMuHfGbM/ATFPWFvxg==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
lYoEi/e8HsDTz6N11EDe/B/iitERmeYndlCklmCluwgb0N4W80JUGVlkd7NlRZHRNhxaNBJPkcjC
n61nO0tb17NwsMwjbY5TF8JWRYTNw1JXCFacvQYrdKv4/7QNQEtwVGiCLxFhOA8aHlWMZIrc2fri
VRMVWaEBcPwCGorlVIM=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
QEw9fEsWFbdX0OQLvYs/gl+zyEOW3ak9TdQVaq+0AXXOT3LIqF7wDxJ6ZBnlf9mNbdsUVH5tAz1o
H8u7ihJl1L3THEvugW+TS8hkvVbEA9rKO2vV15KAj4Lla7UdFT/xDfe79RFarlLI7yGrubjgdoRi
QWy//UKsffG7IWNwmoSuppWiWB4ZHJtkunNyIkm70JPGyZF62VxJg1MTT+5LUbZG5vZjjuHZud9w
xJaKv1tFP/x8RVqLU5gPOqGqTW7/nKO2S+450Vo4D9vAmBVVcXpaL1EbSmCvQ+qJmcQKtf9qYFRV
Zko08hbpHjPxstqvTDro01jRzB8592m4xU2TWA==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
TC7q853CWBPPJgbRfgDV1lmjUwSAtliljShAyNFg8sfRfwDzchthzoSPH1UCHV++E2JXacEKq1lB
UWsNP92U4Xh0/Gu+6esOI0pJb8I+TRTxyBN1I4cRQEfQHcwfhbSdeH3yX9OV3opLEqYmT37hWU+J
zCawYnxVESI0FtRzEXve9gdEWlrKKckrT/hp4mvxxOjvOkOSQBvy0elgUOqh6mEOZl+JnUbsR+Wm
CoZLE1eefMZy3FnVmyDNPv3JPXi88aLXMyimal0MYFkTiS4XJiGT3eAIMIbksehXY+eYi/KFpZWQ
GHpX+lG3UmiWWLwyPakFwKEHbrBc70AlJ2eV9g==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2025.1-2029.x", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
j9nmCKgjPWNChPbpSW6EWLrMA6oCG2JGPoum8px09v0PEAh0DRXZi0J8HPzXUsZgOEMcKpA7X54u
YFcDDCLAQ+urha/eSPbQYHQh4yGCursxAQ1C6LEyNQ2wJ0eLlO2bJeAl/gof06zqsYVM2lLJVNv5
wao1k2bmgPdfpfY3c9vPD0fSMuZPS41EoRS0cQhO5GTZnKdjxm6tEUL3GnTjB8ynSCIbCJUsMtAX
4FRHNa52gudx5B5fagR+lXgFhE7e++rWTJELr7SYB+r5Es8qZLTpCH8TrQxEkV0rY/+e4sAjNE2D
gHw8GD7VcUtc15B8y1BbVmh29qc8Nd3V2i/miA==

`pragma protect key_keyowner="Metrics Technologies Inc.", key_keyname="DSim", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
UkCD6I/Vye4qNoNoa3hIexBXG3xyKUJPAHAjIo7UcNVCDXpMQiYEtPDqExZMfiPlJn2nswCYIfIJ
FYWqMCloKSQyyI/7yZ2EtbyWEklb/P5IyZyvGi6hhFUo/JFTb12b4bK0gZPr+bCDdlVQKTx5GVHz
wptdUJO2omSj8axVMPbLRRtVzlJIZ29dTJ2ATXVXAcBxPnFfHRAMnYYKLeeLExX61vQvpqrkLQHm
XG7hpVzJi56gYKAzxa2BLq072OCVpVS70bfWlhlSTVcSlCrUf+EcarEk4FD8+Ih2NCvrqremG6yn
TtcBn8Xr8M/6zhOYvLi6AD6eArDMKA8n+Ccv8A==

`pragma protect key_keyowner="Atrenta", key_keyname="ATR-SG-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=384)
`pragma protect key_block
A5y5QVZU8yjPexRVPioSiAGohCHD5DX5FVobuMyhcgQRExLUhPvnnS8HOtxTj/2IapEcz68gFMGG
Hpi+m725u85/om/Vze9pGIW9Mn328Kz2FIg3W5EvGstfGwY+48LiAGAmTR269JS4lJGVYWYOz7Xk
S8cEsFd2m7j8iyKtARJzD90+UdXq/cIIh725jC9i8nbgxB364zddvm1Z/DF3JRw1qFp6GGcuRai1
KNcJ1j8c9wtIgktpsteU3e5+bxHEw8NT3gWXUFYjm00NDq97Jals8Jjktmum2nQxoF7ivPacfEey
gnSF6jRMkTsZObzc30hAhs0CEtc33hZLhPLHSn8pQ0WyvKJLHdd5s2yckgTZtqxC1Sbwe7WEgNXe
ZMX3pIkz+aoXsAL7GBLyVBMVQcyMoF0w8QGAaTe8sqatABwPqXidYRqNROTf62IYcMpV89XYgaTv
EwIn/oni9KOFd2BFVxRZbFGGC4IjvigsTBUijI+Dk6kVnDh240clGcc4

`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="CDS_RSA_KEY_VER_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Omtp+lCaqUx7Z4qdFj2zrN8LpCkit2eX4hlMtig+ielGm/x4FSZkpjoFmiqdKFPi2eg0pg09MSai
XyGH68UzAR7Xrj8f1jlIoUmMKp4GcxfdqfTeuu7kWGOJEP6cvgTjSJFj2gawDv7f4yZcltnK2x0L
e4GW/rBTmGvZtKWb2ahjINLxPuh3dDaSaWdb+zVgbtyrI5FrjxBkq+aOxSjyNsqnCx1L0uWbxnkl
88NbXN3dTaECXHNm/fsleayM5hKis7kTv9BFajJMGy+BhQlmIYpE+F5zchnTTFUFJZCz1sX9Fc8e
HcY7irB8mR3ajdzjUZLBQEMktp096Nheq3U75A==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
hpeBLwN9x2ZFDwroYLlUe5GjjDepHik2l0c2s3/6S7JPCRkzQSyt2V1Ad/JewAs/QNp5SXSbYYB4
rQl0My1LDMF3xw43r0g2IbcyHVpPhGp0W5msuQdF67afnsRv90iJYWLMI3QkYGCTWAzl4HrLxFSg
3z8XZRK670IcxznOrlvgHmIKsvubZrBkuc1EynrVb9Nw16QnIx2rc4WgcEXeFf+4i1RoYLDd3gXK
NFCNMdtaRYUThunFP6Z4ViZ5UnDmKq+IMhd31jTaqIlWOBDxPI1+v5RJYxIyTbn4rxlKR2fNbl5/
z4OUjBTd+1GH3I2OXlqmAOvIhpe2Z2HH7nZu/A==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Mt2RhTSUwEIEWeNARbyL+EdfS1UF6nPaL/fKl/7oO2gina93egwCWDLl1fbBtkfaPco0cu4MJ9K3
OraAsyHRlY+MNShmJ1LzAIA1LjZx4y55lu9dlQqSUXR7AW7wVbkg1864mK+hM/1XygU0jvebKNW9
B7xSER+asLO6pxi0mt7uC2PHxLPAYEszFhmnap82TtbDGdQ2qtyekY+ngs+N2fAdsblxVwJruiMl
e6XJ127M8N1mYwhWU2HtRpBOSnnKoHgD9fG51XK/rhk8DxT66QnX9uLPB+H25eDupBJGi1Y5o6x8
hOwZiSUVlBLh7brfzevh7+eRn+7es6wBas0+3w==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 48048)
`pragma protect data_block
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
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
