// Frame buffer using dual-port BRAM inference
// Vivado will automatically map this to BRAM primitives
// 17-bit address x 12-bit data = 131072 x 12 = 1.57 Mb
module frame_buffer (
    // Write port (camera PCLK domain)
    input         clka,
    input  [0:0]  wea,
    input  [16:0] addra,
    input  [11:0] dina,
    // Read port (VGA clock domain)
    input         clkb,
    input  [16:0] addrb,
    output reg [11:0] doutb
);
    reg [11:0] mem [0:131071];

    // integer i;
    // initial begin
    //     for (i = 0; i < 131072; i = i + 1)
    //         mem[i] = 12'h00F; // blue
    // end

    always @(posedge clka) begin
        if (wea[0])
            mem[addra] <= dina;
    end

    always @(posedge clkb) begin
        doutb <= mem[addrb];
    end

endmodule
