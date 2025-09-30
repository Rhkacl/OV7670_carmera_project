// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>



module ov7670_controller (
	input clk,
	input resend,
	output config_finished,
	output sioc,
	inout siod,
	output reset,
	output pwdn,
	output xclk
	);
	
    wire siod_xhdl0;
	reg sys_clk;
	wire [15:0] command;
	wire finished;
	wire taken;
	wire send;
	parameter[7:0] camera_address = 8'h42;
	
	assign siod = siod_xhdl0;
	
	initial
	begin
		sys_clk <= 1'b0;
	end
	
	assign config_finished = finished;
	assign send = ~finished;
	
	i2c_sender u_i2c_sender(
		.clk(clk),
		.taken(taken),
		.siod(siod),
		.sioc(sioc),
		.send(send),
		.id(camera_address),
		.reg_xhdl1(command[15:8]),
		.value(command[7:0])
	);
	
	assign reset = 1'b1;
	assign pwdn = 1'b0;
	assign xclk = sys_clk;
	
	ov7670_registers u_ov7670_registers(
		.clk(clk),
		.advance(taken),
		.command(command),
		.finished(finished),
		.resend(resend)
		);
		
	always @(posedge clk)
	begin
		sys_clk <= ~sys_clk;
	end
	
endmodule