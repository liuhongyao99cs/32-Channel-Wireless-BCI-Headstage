module Tx_232#(
			parameter	integer				SYS_FREQUENCE = 32'd500 * 100000	,	// 50   MHZ
			parameter	integer				BAUD_RATE	  = 32'd115200	 
)(
		    input		wire 				sys_clk,
		    input		wire 				rst_n,
		    input		wire				pi_flag,			//外模块给的一个允许发送的标志位
		    input		wire	[7:0]		pi_tx_data,			//外模块输入的需要发送的数据
					
		    output		reg					po_tx_data,			//输出发送的数据	连接顶层的tx_data,串口端口
		    output		reg					po_tx_flag			//传给控制模块的一个发送字节结束的一个标志位
				);												//该标志位是在bit_cnt==10  即发送停止位时拉高的
				
				
				
localparam  integer		bps_period		=	(SYS_FREQUENCE / BAUD_RATE) - 1; 		
 	
reg				tx_flag;	
reg		[12:0]	cnt_baud;	
reg				bit_flag;										//发送数据的位标志位
reg		[3:0]	bit_cnt;
//wire	[7:0]	pi_tx_data = 8'haa;
//wire			pi_flag =1'b1;
//====================================================================
//		计数器标志位产生						  
//====================================================================	
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				tx_flag	<=		1'b0;
		else if(pi_flag == 1'b1)
				tx_flag	<=		1'b1;
		else if(bit_cnt == 4'd10 &&  bit_flag == 1'b1)
				tx_flag	<=		1'b0;
		else
				tx_flag	<=		tx_flag;
//====================================================================
//		波特率计数器的产生							  
//====================================================================	
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
//		发送数据位的标志位的产生  bit_flag							  
//====================================================================	
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
			bit_flag	<=		1'b0;
		else if(cnt_baud == 13'd1)
				bit_flag	<=		1'b1;
		else 
				bit_flag	<= 1'b0;
//====================================================================
//		发送数据位的数据位计数器						  
//====================================================================	
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				bit_cnt		<=		4'd0;
		else if(bit_cnt == 4'd10 &&  bit_flag == 1'b1)
				bit_cnt		<=		4'd0;		
		else if(bit_flag == 1'b1)
				bit_cnt		<=		bit_cnt + 1'd1;
//====================================================================
//		发送数据						  
//====================================================================	
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)				
				po_tx_data	<=		1'b1;
		else if(bit_cnt == 4'd0  &&  bit_flag == 1'b1)
				po_tx_data		<=		1'b0;						//在发送第一位时发送的是起始位
		else if((bit_cnt >= 4'd1 &&  bit_cnt <=	4'd8)  &&  bit_flag == 1'b1)
				po_tx_data		<=		pi_tx_data[bit_cnt - 1'd1];	//在后面连续发送数据的8个位。在bit_cnt为1时发送pi_tx_data[0]
		else if(bit_cnt == 4'd9  &&  bit_flag == 1'b1)
				po_tx_data		<=		1'b1;						//最后一位发送停止位1
		else 
				po_tx_data		<=		po_tx_data;
//====================================================================
//		发送一个字节数据结束标志位						  
//====================================================================					
always @(posedge sys_clk	or		negedge rst_n)
		if(!rst_n)
				po_tx_flag		<=		1'b0;
		else if(bit_cnt == 4'd10 &&  bit_flag == 1'b1)									//在发送停止位时发出标志位
				po_tx_flag		<=		1'b1;
		else 
				po_tx_flag		<=		1'b0;			
endmodule
