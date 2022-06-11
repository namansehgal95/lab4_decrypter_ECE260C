// Lab5b_tb	  
// testbench for programmable message encryption
// CSE140L     
// Pick a starting sequence;  
// Run lab 4 equivalent to encrypt
module tb_decrypter             ;
	logic       	clk               ;		   // advances simulation step-by-step
	logic       	init              ;          // init (reset=1, start=0) command to DUT
	logic	[7:0]	preamble		  ;
	
	
	logic 	[7:0]	raddr_tb             ,
					waddr_tb             ,
					data_in_tb           ;
	wire  	[7:0] 	data_out_tb          ;
	logic 			mem_tb_control		 ;
	
	
	wire  	      	done              ;          // done flag returned by DUT
	logic 	[7:0] 	pre_length        ,          // bytes before first character in message
					msg_padded2[64]   ,		   // original message, plus pre- and post-padding
					msg_crypto2[64]   ,          // encrypted message according to the DUT
					msg_decryp2[64]   ;          // recovered decrypted message from DUT
	logic 	[4:0] 	LFSR_ptrn[6]      ,		   // 6 possible maximal-length 6-bit LFSR tap ptrns
					LFSR_init         ,		   // NONZERO starting state for LFSR		   
					lfsr_ptrn         ,          // one of 6 maximal length 6-tap shift reg. ptrns
					lfsr2[64]         ;          // states of program 2 decrypting LFSR         
// our original American Standard Code for Information Interchange message follows
// note in practice your design should be able to handle ANY ASCII string
	string     	str2;
	int 		str_len                   ;		   // length of string (character count)
	int 		fault_count;
// displayed encrypted string will go here:
	string     	str_enc2[64]       ;          // decryption program input
	string     	str_dec2[64]       ;          // decrypted string will go here
	int 		ct                        ;
	int 		lk                        ;		   // counts leading spaces for program 3
	int 		pat_sel                   ;          // LFSR pattern select
	logic 		reset;
	
	//decrypter instance
	decryption_wrapper dut_wrapper(
								.clk			(clk),
								.reset			(reset), 
								.init			(init),
								.preamble		(preamble),
								.pre_len		(pre_length),
								// .wr_en_tb		(wr_en_tb		),
								// .raddr_tb		(raddr_tb		),
								// .waddr_tb		(waddr_tb		),
								// .data_in_tb		(data_in_tb		),
								// .data_out_tb	(data_out_tb	),
								// .mem_tb_control	(mem_tb_control	),
								.encrypted_data (msg_crypto2),
								.decrypted_data (msg_decryp2),
								
								.done(done)
							);

	initial begin	 :initial_loop

		clk   = 'b0;
		init  = 'b1;
		// str2 = "@`@@``@@@```@@@@````@@@@@`````@@@@@@``````";
		str2 = "Hey_Hamm_Look_Im_Picasso";
		reset = 'b1;
		@(posedge clk) reset = 'b0;
		// str2 = "Sometimes_Ill_start_a_sentence_and_I_dont_even_know_where_its_going_I_just_hope_I_find_it_along_the_way";
		// str2 = "Im_not_superstitious_but_I_am_a_little_stitious";
		// str2 = "I_knew_exactly_what_to_do_but_in_a_much_more_real_sense_I_had_no_idea_what_to_do";
		// str2 = "Mr_Watson_come_here_I_want_to_see_you";
		// str2 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
		str_len = str2.len     ;
	
		preamble = 8'h7E;
	
		if(str_len>50) begin
		$display("illegally long string of length %d, truncating to 50 chars.",str_len);
		str_len=50;
		end
		// for(int ml=50; ml<64; ml++)
			// str2[ml] = preamble;
		// the 6 possible (constant) maximal-length feedback tap patterns from which to choose
		LFSR_ptrn[0] = 5'h1E;           //  and check for correct results from your DUT
		LFSR_ptrn[1] = 5'h1D;
		LFSR_ptrn[2] = 5'h1B;
		LFSR_ptrn[3] = 5'h17;
		LFSR_ptrn[4] = 5'h14;
		LFSR_ptrn[5] = 5'h12;
		
		// set preamble lengths for the program runs (always > 6)
		// ***** choose any value > 6 *****
		pre_length = 9;    // values 7 to 12 enforced by test bench
		if(pre_length < 7) begin
			$display("illegally short preamble length chosen, overriding with 7");
			pre_length =  7;
		end                       // override < 6 with a legal value
		if(pre_length > 12) begin
			$display("illegally long preamble length chosen, overriding with 12");
			pre_length = 12;
		end  
		else
			$display("preamble length = %d",pre_length);

		// select LFSR tap pattern
		// ***** choose any value < 6 *****
		pat_sel  =  2;
		if(pat_sel > 5) begin 
			$display("illegal pattern select chosen, overriding with 3");
			pat_sel = 3;                         // overrides illegal selections
		end  
		else
			$display("tap pattern %d selected",pat_sel);
			
		// set starting LFSR state for program 
		// ***** choose any 6-bit nonzero value *****
		LFSR_init = 5'h01;                     // for program 2 run
		if(!LFSR_init) begin
			$display("illegal zero LFSR start pattern chosen, overriding with 6'h01");
			LFSR_init = 5'h01;                   // override 0 with a legal (nonzero) value
		end
		else
			$display("LFSR starting pattern = %b",LFSR_init);
    
		$display("original message string length = %d",str_len);
		
		// section not used {
		// for(lk = 0; lk<str_len; lk++)
			// if(str2[lk]==preamble) continue;	       // count leading ~ chars in string
		// else 
			// break;                          // we shall add these to preamble pad length
		
		// $display("embedded leading underscore count = %d",lk);
		// }
		
		
		// precompute encrypted message
		lfsr_ptrn = LFSR_ptrn[pat_sel];   //taps (randomized by pat_sel)  // select one of the 6 permitted tap ptrns
		// write the three control settings into data_memory of DUT

		lfsr2[0]     = LFSR_init;              // any nonzero value (zero may be helpful for debug)
		$display("run encryption of this original message: ");
		$display("%s",str2)        ;           // print original message in transcript window
		$display();
		$display("LFSR_ptrn = %h, LFSR_init = %h %h",lfsr_ptrn,LFSR_init,lfsr2[0]);
		for(int j=0; j<64; j++) 			   // pre-fill message_padded with ASCII ~ characters
			msg_padded2[j] = preamble;         
		for(int l=0; l<str_len; l++)  		   // overwrite up to 60 of these spaces w/ message itself
			msg_padded2[pre_length+l] = byte'(str2[l]); 

		// compute the LFSR sequence
		for (int ii=0;ii<63;ii++) begin :lfsr_loop
			lfsr2[ii+1] = (lfsr2[ii]<<1)+(^(lfsr2[ii]&lfsr_ptrn));
			// $display("lfsr_ptrn %d = %h",ii,lfsr2[ii]);
		end	  :lfsr_loop

		// encrypt the message
		for (int i=0; i<64; i++) begin		   // testbench will change on falling clocks
			msg_crypto2[i]        = msg_padded2[i] ^ lfsr2[i];  //{1'b0,LFSR[6:0]};	   // encrypt 7 LSBs
			$display("LFSR = %h, msg_bit = %h, msg_crypto = %h",lfsr2[i],msg_padded2[i],msg_crypto2[i]);
			str_enc2[i]           = string'(msg_crypto2[i]);
		end
		
		$display("here is the original message with %s preamble padding", preamble);
		for(int jj=0; jj<64; jj++)
			$write("%s",msg_padded2[jj]);
			
		$display("\n");
		$display("here is the padded and encrypted pattern in ASCII");
		for(int jj=0; jj<64; jj++)
			$write("%s",str_enc2[jj]);
			
		$display("\n");
		$display("here is the padded pattern in hex"); 
		for(int jj=0; jj<64; jj++)
			$write(" %h",msg_padded2[jj]);
		$display("\n");

		// run decryption program 
		// mem_tb_control = 1;
		// repeat(5) @(posedge clk); // add 5 cycle delay
		// for(int qp=0; qp<64; qp++) begin
			// @(posedge clk);
			// wr_en_tb   <= 'b1;                   // turn on memory write enable
			// waddr_tb   <= qp;                 // write encrypted message to mem [0:63]
			// data_in_tb <= msg_crypto2[qp];
			// dut.dm1.core[qp] <= msg_crypto2[qp];
		// end

		repeat(5) @(posedge clk); // add 5 cycle delay
		@(posedge clk) 
			init <= 'b0 ;
		repeat(6) @(posedge clk);              // wait for 6 clock cycles of nominal 10ns each
		
		wait(done);                            // wait for DUT's done flag to go high
		#10ns $display("done at time %t",$time);
		//$display("match = %b  foundit = %d",dut.match,dut.foundit);
		
		// read memory post decryption
		// mem_tb_control = 1;
		// repeat(5) @(posedge clk); // add 5 cycle delay
		// for(int nmn=0; nmn<64; nmn++) begin
			// @(posedge clk);
			// raddr_tb   	<= nmn+64; 
			// #1ns;
			// msg_decryp2[nmn] <= data_out_tb ;
			// dut.dm1.core[qp] <= msg_crypto2[qp];
		// end
		// mem_tb_control = 0;
		
		
		$display("dut decryption = ");
		for(int q=0; q<64-pre_length; q++)
			$writeh("  ",msg_decryp2[q]);		       
		$display();
		$display("run decryption:");

		for(int nn=0; nn<64; nn++)			   // count leading underscores
			if(str2[nn]==preamble) 
				ct++; 
			else 
			break;
		$display("ct = %d",ct);
		// for(int n=0; n<str_len+1; n++) begin
			// @(posedge clk);
				// raddr_tb          <= n;
			// @(posedge clk);
				// msg_decryp2[n] <= data_out_tb;
		// end
		for(int rr=0; rr<str_len+1; rr++)
			str_dec2[rr] = string'(msg_decryp2[rr]);
		@(posedge clk)
		for(int qq=0; qq<(64-pre_length); qq++) begin
			$write("From TB = %s, FROM DUT = %s\n",msg_padded2[qq+pre_length],msg_decryp2[qq]);
			$writeh("   ");
			if(msg_padded2[qq+pre_length] != msg_decryp2[qq]) 
				fault_count++;
		end
		$display();
   
		for(int ss=0; ss<str_len; ss++)
			$write("%s",str_dec2[ss]);
		$write("\n");
		$display("fault_count = %d",fault_count); 
		$write("Final Decrypted string = ");
		
		// for(int qq=64; qq<(64+str_len); qq++) 
			// $write("%s",dut.dm1.core[qq]);
		
		$display("\n");  
//    $display("%d bench msg: %h dut msg: %h    %s",
//          n, str2[n+ct], dut.dm1.core[n], dut.dm1.core[n]);   
//    $fclose(fi);      
		#20ns $stop;
	end  :initial_loop

	always begin							 // continuous loop
		#5ns clk = 1;							 // clock tick
		#5ns clk = 0;							 // clock tock
	end										 // continue

endmodule