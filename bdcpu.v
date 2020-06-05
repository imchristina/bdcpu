module bdcpu (
	input clock,
	input reset,
	output [7:0] reg_out_out,
	output mem_output_enable,
	output mem_write_enable,
	output [3:0] mem_address,
	inout [7:0] mem_data
);
	wire [7:0] bus;
	
	wire pc_increment_enable, pc_output_enable, pc_write_enable;
	bdcpu_program_counter pc (clock, reset, pc_increment_enable, pc_output_enable, pc_write_enable, bus);
	
	wire reg_a_output_enable, reg_a_write_enable;
	wire [7:0] reg_a_out;
	bdcpu_register reg_a (clock, reg_a_output_enable, reg_a_write_enable, reg_a_out, bus);
	
	wire reg_b_output_enable, reg_b_write_enable;
	wire [7:0] reg_b_out;
	bdcpu_register reg_b (clock, reg_b_output_enable, reg_b_write_enable, reg_b_out, bus);
	
	wire reg_out_write_enable;
	bdcpu_register reg_out (clock, 1'b0, reg_out_write_enable, reg_out_out, bus);
	
	wire alu_output_enable, alu_subtract, alu_zero, alu_carry;
	bdcpu_alu alu (clock, reg_a_out, reg_b_out, alu_output_enable, alu_subtract, alu_zero, alu_carry, bus);
	
	wire mem_address_enable;
	bdcpu_memory_interface mem (clock, mem_output_enable, mem_write_enable, mem_address_enable, mem_address, mem_data, bus);
	
	bdcpu_control control (
		clock,
		reset,
		alu_zero,
		alu_carry,
		pc_increment_enable,
		pc_output_enable,
		pc_write_enable,
		reg_a_output_enable,
		reg_a_write_enable,
		reg_b_output_enable,
		reg_b_write_enable,
		reg_out_write_enable,
		alu_output_enable,
		alu_subtract,
		mem_output_enable,
		mem_write_enable,
		mem_address_enable,
		bus
	);
endmodule

module bdcpu_program_counter (
	input clock,
	input reset,
	input increment_enable,
	input output_enable,
	input write_enable,
	inout [7:0] bus
);
	reg [3:0] value = 1'b0;
	
	assign bus[3:0] = output_enable ? value : {4{1'bz}};
	
	always @(posedge clock or negedge reset) begin
		if (~reset)
			value = 1'b0;
		else begin
			if (increment_enable)
				value <= value + 1'b1;
			if (write_enable)
				value <= bus[3:0];
		end
	end
endmodule

module bdcpu_register (
	input clock,
	input output_enable,
	input write_enable,
	output [7:0] out,
	inout [7:0] bus
);
	reg [7:0] value;
	assign out = value;
	
	assign bus = output_enable ? value : {8{1'bz}};
	
	always @(posedge clock) begin
		if (write_enable)
			value <= bus;
	end
endmodule

module bdcpu_alu (
	input clock,
	input [7:0] reg_a,
	input [7:0] reg_b,
	input output_enable,
	input subtract,
	output reg zero,
	output reg carry,
	inout [7:0] bus
);
	wire [8:0] result;
	
	assign result = subtract ? reg_a - reg_b : reg_a + reg_b;
	assign bus = output_enable ? result[7:0] : {8{1'bz}};
	
	always @(posedge clock) begin
		if (output_enable) begin
			zero <= (result[7:0] == 8'd0);
			carry <= result[8];
		end
	end
endmodule

module bdcpu_memory_interface (
	input clock,
	input output_enable,
	input write_enable,
	input address_enable,
	output reg [3:0] mem_address,
	inout [7:0] mem_data,
	inout [7:0] bus
);
	
	assign bus = output_enable ? mem_data : {8{1'bz}};
	assign mem_data = write_enable ? bus : {8{1'bz}};
	
	always @(posedge clock) begin
		if (address_enable)
			mem_address <= bus[3:0];
	end
endmodule

module bdcpu_control (
	input clock,
	input reset,
	input alu_zero,
	input alu_carry,
	output reg pc_increment_enable,
	output reg pc_output_enable,
	output reg pc_write_enable,
	output reg reg_a_output_enable,
	output reg reg_a_write_enable,
	output reg reg_b_output_enable,
	output reg reg_b_write_enable,
	output reg reg_out_write_enable,
	output reg alu_output_enable,
	output reg alu_subtract,
	output reg mem_output_enable,
	output reg mem_write_enable,
	output reg mem_address_enable,
	inout [7:0] bus
);
	reg [7:0] instruction;
	reg [2:0] step;
	
	reg control_input_enable, control_output_enable, control_halt, control_step_reset;
	
	assign bus = control_output_enable ? {4'd0, instruction[3:0]} : {8{1'bz}};
	
	wire [3:0] opcode;
	assign opcode = instruction[7:4];
	
	always @(*) begin
		// Disable everything by default
		pc_increment_enable = 1'b0;
		pc_output_enable = 1'b0;
		pc_write_enable = 1'b0;
		reg_a_output_enable = 1'b0;
		reg_a_write_enable = 1'b0;
		reg_b_output_enable = 1'b0;
		reg_b_write_enable = 1'b0;
		reg_out_write_enable = 1'b0;
		alu_output_enable = 1'b0;
		alu_subtract = 1'b0;
		mem_output_enable = 1'b0;
		mem_write_enable = 1'b0;
		mem_address_enable = 1'b0;
		
		control_input_enable = 1'b0;
		control_output_enable = 1'b0;
		control_halt = 1'b0;
		control_step_reset = 1'b0;
		
		case (step)
			3'd0: begin
				pc_output_enable = 1'b1;
				mem_address_enable = 1'b1;
			end
			3'd1: begin
				mem_output_enable = 1'b1;
				control_input_enable = 1'b1;
				pc_increment_enable = 1'b1;
			end
			3'd2: begin
				case (opcode)
					4'b0001, 4'b0010, 4'b0011, 4'b0100: begin // LDA 2, ADD 2, SUB 2, STA 2
						control_output_enable = 1'b1;
						mem_address_enable = 1'b1;
					end
					4'b0101: begin // LDI 2
						control_output_enable = 1'b1;
						reg_a_write_enable = 1'b1;
						control_step_reset = 1'b1;
					end
					4'b0110: begin // JMP 2
						control_output_enable = 1'b1;
						pc_write_enable = 1'b1;
						control_step_reset = 1'b1;
					end
					4'b0111: begin // JC 2
						if (alu_carry) begin
							control_output_enable = 1'b1;
							pc_write_enable = 1'b1;
						end
						control_step_reset = 1'b1;
					end
					4'b1000: begin // JZ 2
						if (alu_zero) begin
							control_output_enable = 1'b1;
							pc_write_enable = 1'b1;
						end
						control_step_reset = 1'b1;
					end
					4'b1110: begin // OUT 2
						reg_a_output_enable = 1'b1;
						reg_out_write_enable = 1'b1;
						control_step_reset = 1'b1;
					end
					4'b1111: control_halt = 1'b1; // HLT 2
				endcase
			end
			3'd3: begin
				case (opcode)
					4'b0001: begin // LDA 3
						mem_output_enable = 1'b1;
						reg_a_write_enable = 1'b1;
						control_step_reset = 1'b1;
					end
					4'b0010, 4'b0011: begin // ADD 3, SUB 3
						mem_output_enable = 1'b1;
						reg_b_write_enable = 1'b1;
					end
					4'b0100: begin // STA 3
						reg_a_output_enable = 1'b1;
						mem_write_enable = 1'b1;
						control_step_reset = 1'b1;
					end
				endcase
			end
			3'd4: begin
				case (opcode)
					4'b0010: begin // ADD 4
						alu_output_enable = 1'b1;
						reg_a_write_enable = 1'b1;
						control_step_reset = 1'b1;
					end
					4'b0011: begin // SUB 4
						alu_output_enable = 1'b1;
						reg_a_write_enable = 1'b1;
						alu_subtract = 1'b1;
						control_step_reset = 1'b1;
					end
				endcase
			end
		endcase
	end
	
	always @(negedge clock or negedge reset) begin
		if (~reset)
			step <= 1'b0;
		else begin
			if (control_input_enable)
				instruction <= bus;
			
			if (control_step_reset)
				step <= 1'b0;
			else if (~control_halt)
				step <= step + 1'b1;
		end
	end
endmodule

module testbench ();
	reg clock = 0;
	always #1 clock = ~clock;
	
	reg reset = 1'b0;
	wire cpu_mem_output, cpu_mem_write;
	wire [3:0] cpu_mem_address;
	wire [7:0] out, mem_data;
	bdcpu cpu (clock, reset, out, cpu_mem_output, cpu_mem_write, cpu_mem_address, mem_data);
	
	reg [7:0] mem [16:0];
	assign mem_data = cpu_mem_output ? mem[cpu_mem_address] : {8{1'bz}};
	always @(posedge clock) begin
		if (cpu_mem_write)
			mem[cpu_mem_address] <= mem_data;
	end
	
	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);
		
		// Fib
		mem[0] <= 8'b01010001; // LDI
		mem[1] <= 8'b01001110; // STA
		mem[2] <= 8'b01010000; // LDI
		mem[3] <= 8'b11100000; // OUT
		mem[4] <= 8'b00101110; // ADD
		mem[5] <= 8'b01001111; // STA
		mem[6] <= 8'b00011110; // LDA
		mem[7] <= 8'b01001101; // STA
		mem[8] <= 8'b00011111; // LDA
		mem[9] <= 8'b01001110; // STA
		mem[10] <= 8'b00011101; // LDA
		mem[11] <= 8'b01110000; // JC
		mem[12] <= 8'b01100011; // JMP
		mem[13] <= 8'b00000000;
		mem[14] <= 8'b00000000;
		mem[15] <= 8'b00000000;
		
		// Add Loop
		/*mem[0] <= 8'b00011110;
		mem[1] <= 8'b00101111;
		mem[2] <= 8'b01110100;
		mem[3] <= 8'b01100001;
		mem[4] <= 8'b11110000;
		mem[14] <= 8'b11111100;
		mem[15] <= 8'b00000001;*/
		
		#2 reset <= 1'b1;
		#10000 $finish;
	end
endmodule
