module decryption_wrapper (
	input          	clk, 
	input 			reset,
	input			init,
	input 	[7:0]	preamble,
	input 	[3:0] 	pre_len,
	
	// Memory Interface
	// input 			wr_en_tb	,
	// input 	[7:0]	raddr_tb	,
	// input 	[7:0]	waddr_tb	,
	// input 	[7:0]	data_in_tb	,
	// output 	logic [7:0]	data_out_tb	,
	// input 			mem_tb_control,
	input 		[7:0]	encrypted_data[0:63],
	output logic [7:0]	decrypted_data[0:63],
	
	output logic   done
	);
	
	logic done_dut;
	logic mem_tb_control;
	logic [7:0] data_in_tb;
	logic [7:0] data_out_tb;
	logic [7:0] waddr_tb;
	logic [7:0] raddr_tb;
	logic [7:0] counter;
	logic  		wr_en_tb;
	logic 		init_dut;
	
	
	decrypter_top_level dut(
							.clk			(clk),
							.init			(init_dut),
							.preamble		(preamble),
							.pre_len		(pre_len),
							.wr_en_tb		(wr_en_tb		),//
							.raddr_tb		(raddr_tb		),//
							.waddr_tb		(waddr_tb		),//
							.data_in_tb		(data_in_tb		),//
							.data_out_tb	(data_out_tb	),//
							.mem_tb_control	(mem_tb_control	),//
							
							.done(done_dut)
						);
						
	logic init_s0, init_s1, init_s2;
	always@(posedge clk or posedge reset)
	if(reset)
	begin
		init_s0 <= 0;//init;
		init_s1 <= 0;//init_s0;
		init_s2 <= 0;//init_s1;
	end
	else
	begin
		init_s0<= init;
		init_s1 <= init_s0;
		init_s2 <= init_s1;
	end
		
	logic [2:0] mem_state;
	always@(posedge clk or posedge reset)
	if(reset)
	begin
		mem_state 	<= 0;
		counter 	<= 0;
	end
	else
	begin
		case(mem_state)
		'd0 : begin
				if(init_s1 && !init_s2)
				begin
					mem_state <= 'd1;
					counter <= 0;
				end
			end
		
		'd1 : begin
				if(counter<63)
				begin
					counter= counter + 1;
				end
				else
				begin
					counter = 'd0;
					mem_state = 'd2;
				end
			end
		'd2 : begin
				if(done_dut)
					mem_state = 'd3;
			end
		'd3 : begin
				if(counter<63)
				begin
					decrypted_data[counter] = data_out_tb;
					counter = counter + 1;
				end
				else
				begin
					counter = 0;
					mem_state = 'd4;
				end
			end
		'd4 : begin
				mem_state = 'd0;
				done 	  = 'd1;
			end
		default :  begin
				if(init_s1 && !init_s2)
				begin
					mem_state <= 'd1;
					counter <= 0;
				end
			end
		endcase
	end
	
	assign data_in_tb = encrypted_data[counter];
	assign init_dut   = mem_state == 'd1;
	assign waddr_tb  = counter;
	assign wr_en_tb   = mem_state=='d1;
	assign mem_tb_control	= 	mem_state=='d1 ? 1 : 
								mem_state=='d3 ? 1 :
								0;
	assign raddr_tb   = 64 + counter;

endmodule
	
	
	