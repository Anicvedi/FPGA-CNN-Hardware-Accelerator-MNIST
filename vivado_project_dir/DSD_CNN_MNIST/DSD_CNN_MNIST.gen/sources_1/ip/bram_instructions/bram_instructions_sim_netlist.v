// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Wed Mar 18 17:10:22 2026
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
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *) input [15:0]dina;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [15:0]douta;

  wire [9:0]addra;
  wire clka;
  wire [15:0]dina;
  wire [15:0]douta;
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
  wire [15:0]NLW_U0_doutb_UNCONNECTED;
  wire [9:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [9:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [15:0]NLW_U0_s_axi_rdata_UNCONNECTED;
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
  (* C_COUNT_18K_BRAM = "1" *) 
  (* C_COUNT_36K_BRAM = "0" *) 
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
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     1.51805 mW" *) 
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
  (* C_READ_WIDTH_A = "16" *) 
  (* C_READ_WIDTH_B = "16" *) 
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
  (* C_WRITE_WIDTH_A = "16" *) 
  (* C_WRITE_WIDTH_B = "16" *) 
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
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(NLW_U0_doutb_UNCONNECTED[15:0]),
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
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[15:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 19040)
`pragma protect data_block
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
TeU=
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
