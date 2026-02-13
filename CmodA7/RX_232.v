module RX_232#(
			parameter	integer				SYS_FREQ     = 32'd500 * 100000	,	// 50   MHZ
			parameter	integer				BAUD_RATE	  = 32'd115200	 
)(
		    input		wire 				sys_clk,
		    input		wire 				rst_n,
		    input		wire				pi_flag,			//ÍâÄ£¿é¸øµÄÒ»¸öÔÊÐí·¢ËÍµÄ±êÖ¾Î»
		    input		wire	[7:0]		pi_tx_data,			//ÍâÄ£¿éÊäÈëµÄÐèÒª·¢ËÍµÄÊý¾Ý
					
		    output		reg					po_tx_data,			//Êä³ö·¢ËÍµÄÊý¾Ý	Á¬½Ó¶¥²ãµÄtx_data,´®¿Ú¶Ë¿Ú
		    output		reg					po_tx_flag			//´«¸ø¿ØÖÆÄ£¿éµÄÒ»¸ö·¢ËÍ×Ö½Ú½áÊøµÄÒ»¸ö±êÖ¾Î»
				);												//¸Ã±êÖ¾Î»ÊÇÔÚbit_cnt==10  ¼´·¢ËÍÍ£Ö¹Î»Ê±À­¸ßµÄ
				
				
				
localparam  integer		bps_period		=	(SYS_FREQ / BAUD_RATE) - 1; 		
 	
reg				tx_flag;	
reg		[12:0]	cnt_baud;	
reg				bit_flag;										//·¢ËÍÊý¾ÝµÄÎ»±êÖ¾Î»
reg		[3:0]	bit_cnt;

always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				tx_flag	<=		1'b0;
		else if(pi_flag == 1'b1)
				tx_flag	<=		1'b1;
		else if(bit_cnt == 4'd10 &&  bit_flag == 1'b1)
				tx_flag	<=		1'b0;
		else
				tx_flag	<=		tx_flag;

always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				cnt_baud	<=	13'd0;
		else if(tx_flag == 1'b1)
				begin
					if(cnt_baud == bps_period)
						cnt_baud	<=		13'd0;
					else 
						cnt_baud	<=		cnt_baud + 1'd1;
				end
		else
				cnt_baud	<=		13'd0;
//====================================================================
//		·¢ËÍÊý¾ÝÎ»µÄ±êÖ¾Î»µÄ²úÉú  bit_flag							  
//====================================================================	
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
			bit_flag	<=		1'b0;
		else if(cnt_baud == 13'd1)
				bit_flag	<=		1'b1;
		else 
				bit_flag	<= 1'b0;
//====================================================================
//		·¢ËÍÊý¾ÝÎ»µÄÊý¾ÝÎ»¼ÆÊýÆ÷						  
//====================================================================	
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				bit_cnt		<=		4'd0;
		else if(bit_cnt == 4'd10 &&  bit_flag == 1'b1)
				bit_cnt		<=		4'd0;		
		else if(bit_flag == 1'b1)
				bit_cnt		<=		bit_cnt + 1'd1;

always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)				
				po_tx_data	<=		1'b1;
		else if(bit_cnt == 4'd0  &&  bit_flag == 1'b1)
				po_tx_data		<=		1'b0;						
		else if((bit_cnt >= 4'd1 &&  bit_cnt <=	4'd8)  &&  bit_flag == 1'b1)
				po_tx_data		<=		pi_tx_data[bit_cnt - 1'd1];	
		else if(bit_cnt == 4'd9  &&  bit_flag == 1'b1)
				po_tx_data		<=		1'b1;						//×îºóÒ»Î»·¢ËÍÍ£Ö¹Î»1
		else 
				po_tx_data		<=		po_tx_data;
				
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				po_tx_flag		<=		1'b0;
		else if(bit_cnt == 4'd10 &&  bit_flag == 1'b1)									//ÔÚ·¢ËÍÍ£Ö¹Î»Ê±·¢³ö±êÖ¾Î»
				po_tx_flag		<=		1'b1;
		else 
				po_tx_flag		<=		1'b0;			
endmodule