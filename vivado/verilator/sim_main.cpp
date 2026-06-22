// DESCRIPTION: Verilator: Verilog example module
//
// This file ONLY is placed under the Creative Commons Public Domain, for
// any use, without warranty, 2017 by Wilson Snyder.
// SPDX-License-Identifier: CC0-1.0
//======================================================================

// For std::unique_ptr
#include <memory>

// Include common routines
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vsim_i2c.h"

// Legacy function required only so linking works on Cygwin and MSVC++
double sc_time_stamp() { return 0; }

int main(int argc, char** argv) {
    // This is a more complicated example, please also see the simpler examples/make_hello_c.

    // Create logs/ directory in case we have traces to put under it
    Verilated::mkdir("logs");

    // Construct a VerilatedContext to hold simulation time, etc.
    // Multiple modules (made later below with Vsim_i2c) may share the same
    // context to share time, or modules may have different contexts if
    // they should be independent from each other.

    // Using unique_ptr is similar to
    // "VerilatedContext* contextp = new VerilatedContext" then deleting at end.
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    // Do not instead make Vsim_i2c as a file-scope static variable, as the
    // "C++ static initialization order fiasco" may cause a crash

    // Set debug level, 0 is off, 9 is highest presently used
    // May be overridden by commandArgs argument parsing
    contextp->debug(0);

    // Randomization reset policy
    // May be overridden by commandArgs argument parsing
    contextp->randReset(2);

    // Verilator must compute traced signals
    contextp->traceEverOn(true);

    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    // This needs to be called before you create any model
    contextp->commandArgs(argc, argv);

    // Construct the Verilated model, from Vsim_i2c.h generated from Verilating "top.v".
    // Using unique_ptr is similar to "Vsim_i2c* top = new Vsim_i2c" then deleting at end.
    // "TOP" will be the hierarchical name of the module.
    const std::unique_ptr<Vsim_i2c> top{new Vsim_i2c{contextp.get(), "TOP"}};

    // VCD trace setup
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("logs/vlt_dump.vcd");

    // Set Vsim_i2c's input signals
    top->rst = 1;
    top->clk = 0;

    // Simulate until config_done
    while (true) {
        contextp->timeInc(1);

        top->clk = !top->clk;

        if (!top->clk) {
            top->rst = (contextp->time() < 20) ? 1 : 0;
        }

        top->eval();
        tfp->dump(contextp->time());

        if (top->config_done) {
            VL_PRINTF("config_done at time %" PRId64 "\n", contextp->time());
            // 100 클록 더 실행
            for (int i = 0; i < 200; i++) {
                contextp->timeInc(1);
                top->clk = !top->clk;
                top->eval();
                tfp->dump(contextp->time());
            }
            break;
        }
    }

    tfp->close();

    // Final model cleanup
    top->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif

    // Final simulation summary
    contextp->statsPrintSummary();

    // Return good completion status
    // Don't use exit() or destructor won't get called
    return 0;
}
