# AXI4-Lite RAM Slave – SystemVerilog RTL Design & Verification

## Overview

This project implements a simplified **AXI4-Lite Slave Interface** using SystemVerilog RTL, integrated with a synchronous single-port RAM. The design demonstrates memory-mapped read and write transactions using the five independent AXI4-Lite channels.

The project focuses on understanding AXI4-Lite protocol fundamentals, valid-ready handshaking, transaction control, synchronous memory access, and response generation.

## Features

- Implementation of AXI4-Lite-style read and write transactions.
- Separate handling of Write Address (AW) and Write Data (W) channels.
- Independent capture of write address and write data.
- Write Response (B) generation with `BVALID` and `BREADY` handshaking.
- Read Address (AR) acceptance and synchronous RAM access.
- Read Data (R) response generation with `RVALID` and `RREADY` handshaking.
- Single-port RAM integration with serialized read and write operations.
- Parameterized data width, address width, and memory depth.
- SystemVerilog testbench for functional verification.

## Architecture

The design consists of two primary blocks:

### 1. AXI4-Lite Slave Controller

The controller manages the five AXI4-Lite channels:

| Channel | Purpose |
|---|---|
| AW – Write Address | Receives the write address |
| W – Write Data | Receives the write data |
| B – Write Response | Indicates completion of a write transaction |
| AR – Read Address | Receives the read address |
| R – Read Data | Returns the requested read data |

The controller uses an FSM-based approach to coordinate memory transactions and generate appropriate responses.

### 2. Synchronous RAM

A parameterized single-port RAM is connected to the AXI4-Lite slave controller.

**Default configuration:**

| Parameter | Value |
|---|---:|
| Data Width | 32 bits |
| Address Width | 4 bits |
| Memory Depth | 16 words |
| Total Capacity | 512 bits (64 bytes) |

The RAM supports synchronous read and write operations.

## Transaction Flow

### Write Transaction

1. The slave accepts the write address through the AW channel.
2. The write data is accepted independently through the W channel.
3. Once both address and data are available, the controller initiates the RAM write.
4. The slave generates a write response through the B channel.
5. The response remains valid until the master asserts `BREADY`.

### Read Transaction

1. The slave accepts the read address through the AR channel.
2. The controller initiates a synchronous RAM read.
3. The RAM output is captured by the controller.
4. The requested data is returned through the R channel.
5. The read response remains valid until the master asserts `RREADY`.

## Verification

A SystemVerilog testbench is used to verify the functionality of the AXI4-Lite slave.

The verification focuses on:

- Write address and write data handshaking.
- RAM write operation.
- Read address handshaking.
- RAM read operation.
- Write and read response generation.
- Valid-ready protocol behavior.
- Read-after-write functionality.

## Project Structure

```text
AXI4-Lite-RAM-Slave/
│
├── rtl/
│   ├── axi4_lite_top.sv
│   └── ram_design.sv
│
├── tb/
│   └── tb_axi4_lite_ram.sv
│
└── README.md
```

*Adjust the folder names and filenames to match your actual repository.*

## Tools & Technologies

- **HDL:** SystemVerilog
- **Simulation:** Synopsys VCS / compatible SystemVerilog simulator
- **Verification:** SystemVerilog Testbench
- **Version Control:** Git & GitHub

## Scope and Limitations

This is an educational, single-beat AXI4-Lite-style implementation intended to demonstrate basic protocol operation and memory interfacing.

- Burst transactions are not supported.
- Full-word writes are supported; byte strobes (`WSTRB`) are not implemented.
- The single-port RAM serializes read and write operations.
- Advanced AXI features such as multiple outstanding transactions and protection attributes are outside the current scope.

## Future Improvements

- Add byte-enable support using `WSTRB`.
- Improve verification with assertions and functional coverage.
- Develop a reusable SystemVerilog verification environment.
- Extend the design with additional AXI protocol features.

## Author

**Sourik Choudhury**

Electronics and Communication Engineering | RTL Design & Functional Verification

---

*This project is developed as part of my learning journey in digital design, AMBA protocols, and functional verification.*