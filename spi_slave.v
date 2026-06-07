// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 06.2026
// SPI Slave
//
// - SPI mode: 0 (CPOL: 0, CPHA: 0)
// - Address range: 2^7. MSB bit of address byte is used for SPI command bit (SPI_READ_COMMAND=0, SPI_WRITE_COMMAND=1)
// - Register width: 1 byte 
// 
// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 21/08/2020

`define STATE_SPI_IDLE 		3'd0
`define STATE_SPI_COMMAND	3'd1
`define STATE_SPI_WRITE 	3'd2
`define STATE_SPI_READ 		3'd3
`define STATE_SPI_END 		3'd4

`define ERROR_ADD_OUT_OF_RANGE 	8'hFF

module spi_slave
(
	input Clk,
	input iRST_N,
	
	input SCK, 
	input MOSI,
	input SSEL, 
	output reg MISO,
	
	input [7:0] Add2_in,	
	output reg [7:0] Data2_out,
	
	output reg [7:0] debug
);

reg [7:0] Register0, Register1, Register2, Register3, Register4, Register5, Register6, Register7;

reg SCK_metastable, MOSI_metastable, SSEL_metastable;
reg SCK_delay0, MOSI_delay0, SSEL_delay0;
reg SCK_delay1, SSEL_delay1;
reg WrEn, RnW;
reg [3:0] BitCnt;
reg [7:0] ReceivedByte, Data_fromSPI, DataToSend, Data_toSPI, Add_SPI;
reg [2:0] SPI_State;

always @(posedge Clk or negedge iRST_N) begin
	if(!iRST_N) begin
		Register0	<= 8'h0A;
		Register1	<= 8'h0B;
		Register2	<= 8'h0C;
		Register3	<= 8'h0D;
		Register4	<= 8'h0E;
		Register5	<= 8'h10;
		Register6	<= 8'h20;
		Register7	<= 8'h30;
		Data_toSPI 	<= 8'h00;
		Data2_out	<= 8'h00;
		
		SCK_metastable 	<= 1'b0;
		MOSI_metastable <= 1'b0;
		SSEL_metastable <= 1'b0;
		SCK_delay0 	<= 1'b0;	
		MOSI_delay0 	<= 1'b0; 
		SSEL_delay0 	<= 1'b0;
		SCK_delay1 	<= 1'b0;
		SSEL_delay1 	<= 1'b0;
		WrEn 		<= 1'b0;
		RnW		<= 1'b0;
		BitCnt		<= 4'h0;
		ReceivedByte	<= 8'h00;	
		Data_fromSPI	<= 8'h00;
		DataToSend	<= 8'h00;
		Add_SPI		<= 8'h00;
		
		MISO		<= 1'b0;
		
		debug		<= 1'b0;
		
		SPI_State 	<= `STATE_SPI_IDLE;
	end
	else begin
	
		//{{{ READ/WRITE ACCESS
		if (RnW) begin
			case (Add_SPI)
				8'h00: Data_toSPI <= Register0;
				8'h01: Data_toSPI <= Register1;
				8'h02: Data_toSPI <= Register2;
				8'h03: Data_toSPI <= Register3;
				8'h04: Data_toSPI <= Register4;
				8'h05: Data_toSPI <= Register5;
				8'h06: Data_toSPI <= Register6;
				8'h07: Data_toSPI <= Register7;
				default: Data_toSPI <= `ERROR_ADD_OUT_OF_RANGE;
			endcase
		end
		else if (WrEn) begin
			case (Add_SPI)
				8'h00:  Register0 <= Data_fromSPI;
				8'h01:  Register1 <= Data_fromSPI;
				8'h02:  Register2 <= Data_fromSPI;
				8'h03:  Register3 <= Data_fromSPI;
				8'h04:  Register4 <= Data_fromSPI;
				8'h05:  Register5 <= Data_fromSPI;
				8'h06:  Register6 <= Data_fromSPI;
				8'h07:  Register7 <= Data_fromSPI;
			endcase
		end		
		//}}}
		
		//{{{ READ ACCESS 2
		case (Add2_in)
			8'h00: Data2_out <= Register0;
			8'h01: Data2_out <= Register1;
			8'h02: Data2_out <= Register2;
			8'h03: Data2_out <= Register3;
			8'h04: Data2_out <= Register4;
			8'h05: Data2_out <= Register5;
			8'h06: Data2_out <= Register6;
			8'h07: Data2_out <= Register7;
			default: Data2_out <= `ERROR_ADD_OUT_OF_RANGE;
		endcase
		//}}}
		
		//{{{ SPI INTERFACE		
		SCK_metastable 	<= SCK;
		MOSI_metastable <= MOSI;
		SSEL_metastable <= SSEL;
		SCK_delay0 	<= SCK_metastable;	
		MOSI_delay0 	<= MOSI_metastable; 
		SSEL_delay0 	<= SSEL_metastable;
		SCK_delay1 	<= SCK_delay0;
		SSEL_delay1 	<= SSEL_delay0;
		
		WrEn 		<= 1'b0;

		case (SPI_State)		
		
			`STATE_SPI_IDLE: begin
				BitCnt <= 0;
				debug <= debug | 1;
				if (SSEL_delay0 == 0  && SSEL_delay1 == 1)
					SPI_State <= `STATE_SPI_COMMAND;
			end
			
			`STATE_SPI_COMMAND: begin
				debug <= debug | 8'h02;
				if (SCK_delay0 == 1 && SCK_delay1 == 0) begin
					ReceivedByte <= {ReceivedByte[6:0], MOSI_delay0};
					BitCnt <= BitCnt + 1;
				end
				if (BitCnt == 4'h8) begin
					BitCnt 	<= 4'h0;
					Add_SPI	<= {1'b0, ReceivedByte[6:0]};
					RnW 	<= ReceivedByte[7];
					if (ReceivedByte[7] == 1)
						SPI_State <= `STATE_SPI_READ;
					else
						SPI_State <= `STATE_SPI_WRITE;
				end
			end
			
			`STATE_SPI_WRITE: begin
				debug <= debug | 4;
				if (SCK_delay0 == 1 && SCK_delay1 == 0) begin
					ReceivedByte <= {ReceivedByte[6:0], MOSI_delay0};
					BitCnt <= BitCnt + 1;
				end
				if (BitCnt == 4'h8) begin
					WrEn <= 1;		
					Data_fromSPI <= ReceivedByte;
					SPI_State <= `STATE_SPI_END;
				end
			end

			`STATE_SPI_READ: begin
				debug <= debug | 8;
				if (BitCnt == 0) begin
					if (SCK_delay0 == 0 && SCK_delay1 == 1) begin
						MISO <= Data_toSPI[7];
						DataToSend <= {Data_toSPI[6:0], 1'b0};
						BitCnt <= 1;
					end
				end
				else begin
					if (SCK_delay0 == 0 && SCK_delay1 == 1) begin
						MISO <= DataToSend[7];
						DataToSend <= {DataToSend[6:0], 1'b0};
						BitCnt <= BitCnt + 1;
					end
				end
				if (BitCnt == 4'h8) begin
					Data_fromSPI <= ReceivedByte;
					SPI_State <= `STATE_SPI_END;
				end
			end
					
			`STATE_SPI_END: begin
				debug <= debug | 16;
				if (SSEL_delay0)
					SPI_State <= `STATE_SPI_IDLE;				
			end	
						
		endcase
		//}}}

	end
end

endmodule
