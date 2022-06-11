
module decrypter_top_level( 
	input          	clk, 
	input			init,
	input 	[7:0]	preamble,
	input 	[3:0] 	pre_len,
	
	// Memory Interface
	input 			wr_en_tb	,
	input 	[7:0]	raddr_tb	,
	input 	[7:0]	waddr_tb	,
	input 	[7:0]	data_in_tb	,
	output 	logic [7:0]	data_out_tb	,
	input 			mem_tb_control,
	
	output logic   done
	);

// memory interface
	logic          wr_en;
	logic    [7:0] raddr, 
					waddr,
					data_in;
	logic    [7:0] data_out;  
	
	logic          wr_en_mux;
	logic    [7:0] raddr_mux, 
					waddr_mux,
					data_in_mux;
	logic    [7:0] data_out_mux;  
  
	always_comb begin
		if(mem_tb_control)
		begin
			wr_en_mux 	= wr_en_tb;
			raddr_mux 	= raddr_tb;
			waddr_mux 	= waddr_tb;
			data_in_mux	= data_in_tb;
			data_out_tb = data_out_mux;
		end
		else
		begin
			wr_en_mux 	= wr_en;
			raddr_mux 	= raddr;
			waddr_mux 	= waddr;
			data_in_mux	= data_in;
			data_out 	= data_out_mux;
		end
	end
  
  
  
// program counter             
  logic[15:0] cycle_ct = 0;

// LFSR interface
  logic load_LFSR,
        LFSR_en;
  logic[4:0] LFSR_ptrn[6];           // the 6 possible maximal length LFSR patterns
  assign LFSR_ptrn[0] = 5'h1E;
  assign LFSR_ptrn[1] = 5'h1D;
  assign LFSR_ptrn[2] = 5'h1B;
  assign LFSR_ptrn[3] = 5'h17;
  assign LFSR_ptrn[4] = 5'h14;
  assign LFSR_ptrn[5] = 5'h12;
  logic[4:0] start;                  // LFSR starting state
  logic[4:0] LFSR_state[6];          // current states of the 6 LFSRs
  logic[2:0] foundit;                // got a match for one LFSR
  logic[5:0] match;					 // index of foundit
  int i;

  dat_mem dm1(
				.clk		(clk),
				.write_en	(wr_en_mux),
				.raddr		(raddr_mux),
				.waddr		(waddr_mux),
				.data_in	(data_in_mux),
				.data_out	(data_out_mux)
			);                   
/* We need to advance the LFSR(s) once per clock cycle. 
Same with raddr, waddr, since we can physically do one memory read and/or write
per clock cycle. 
*/
  lfsr5 l0(.clk , 
         .en   (LFSR_en)  ,    // 1: advance LFSR on rising clk
         .init (load_LFSR),	   // 1: initialize LFSR
         .taps (5'h1E)     ,	   // tap pattern 0
         .start ,	   // starting state for LFSR
         .state(LFSR_state[0]));		   // LFSR state = LFSR output 

  lfsr5 l1(.clk , 
         .en   (LFSR_en),      // 1: advance LFSR on rising clk
         .init (load_LFSR),	   // 1: initialize LFSR
         .taps (5'h1D) ,		   // tap pattern
         .start ,	   // starting state for LFSR
         .state(LFSR_state[1]));		   // LFSR state = LFSR output 

  lfsr5 l2(.clk , 
         .en   (LFSR_en),      // 1: advance LFSR on rising clk
         .init (load_LFSR),	   // 1: initialize LFSR
         .taps (5'h1B) ,		   // tap pattern
         .start ,	   // starting state for LFSR
         .state(LFSR_state[2]));		   // LFSR state = LFSR output 

  lfsr5 l3(.clk , 
         .en   (LFSR_en),      // 1: advance LFSR on rising clk
         .init (load_LFSR),	   // 1: initialize LFSR
         .taps (5'h17) , 	   // tap pattern
         .start ,	   // starting state for LFSR
         .state(LFSR_state[3]));		   // LFSR state = LFSR output 

  lfsr5 l4(.clk , 
         .en   (LFSR_en),      // 1: advance LFSR on rising clk
         .init (load_LFSR),	   // 1: initialize LFSR
         .taps (5'h14) ,		   // tap pattern
         .start ,	   // starting state for LFSR
         .state(LFSR_state[4]));		   // LFSR state = LFSR output 

  lfsr5 l5(.clk , 
         .en   (LFSR_en),      // 1: advance LFSR on rising clk
         .init (load_LFSR),	   // 1: initialize LFSR
         .taps (5'h12) ,		   // tap pattern
         .start ,	   // starting state for LFSR
         .state(LFSR_state[5]));		   // LFSR state = LFSR output 

 

  always_comb begin
    data_in = {data_out[7:5],(data_out[4:0]^LFSR_state[foundit])};
  end
  
 assign start = data_out[4:0] ^ preamble[4:0];  // since first encrypted character was LFSR_state ^ 0x7E

logic [7:0] temp_check [0:5];
always_comb
begin
	temp_check[0] = {data_out[7:5],(data_out[4:0]^LFSR_state[0])};
	temp_check[1] = {data_out[7:5],(data_out[4:0]^LFSR_state[1])};
	temp_check[2] = {data_out[7:5],(data_out[4:0]^LFSR_state[2])};
	temp_check[3] = {data_out[7:5],(data_out[4:0]^LFSR_state[3])};
	temp_check[4] = {data_out[7:5],(data_out[4:0]^LFSR_state[4])};
	temp_check[5] = {data_out[7:5],(data_out[4:0]^LFSR_state[5])};
end

// program counter
  always @(posedge clk) begin  :clock_loop
//    initQ <= init;             // may not be needed
    if(init) begin
      cycle_ct <= 'b0;
	  match    <= 6'h3F;
	end
    else begin
      cycle_ct <= cycle_ct + 1;
	  if(cycle_ct<=6 && cycle_ct>=2) begin
	    $display("data_out = %h",data_out);
	    for(i=0; i<6; i++) begin
	      match[i] <= match[i] & ({data_out[7:5],(data_out[4:0]^LFSR_state[i])} == preamble);
		  $display("match[i] = %h %d",match[i],i);
		end
      end
    end
  end  

  always_comb case(match)
    6'b10_0000: foundit = 'd5;
	6'b01_0000: foundit = 'd4;
	6'b00_1000: foundit = 'd3;
	6'b00_0100: foundit = 'd2;
	6'b00_0010: foundit = 'd1;
	default	  : foundit = 'd0;
  endcase

  always_comb begin 
//defaults
    load_LFSR = 'b0; 
    LFSR_en   = 'b0;   
	wr_en     = 'b0;
  case(cycle_ct)
	0: begin 
           raddr     = 'd0;
		   waddr     = 'd64;
	     end		       // no op
	1: begin 
           load_LFSR = 'b1;
           raddr     = 'd0;
		   waddr     = 'd64;
	     end		       // no op
	2  : begin				   
           LFSR_en   = 'b1;	   // initialize the 6 LFSRs     
           raddr     = 'd0;
		   waddr     = 'd64;
         end
	3  : begin			       // training seq.
	       LFSR_en = 'b1;
		   raddr++;
		   waddr = 'd64;
		 end
	72  : begin //works with 66 also
            //done = 'b1;
 		    raddr =	'd0;
 		    waddr = 'd64; 
	     end
	default: begin
	       LFSR_en = 'b1;
           raddr ++; 
           if(cycle_ct>(pre_len+1)) begin
			 wr_en = 'b1;
			 if(cycle_ct>(pre_len+2))
			   waddr++;
		   end
		   else begin
		     waddr = 'd64;
			 wr_en = 'b0;
		   end
	     end
  endcase
end

assign done = cycle_ct === 'd72;

endmodule
