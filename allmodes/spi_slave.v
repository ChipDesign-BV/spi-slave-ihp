// Koen Van Caekenberghe (koen.vancaekenberghe@chipdesign.be), ChipDesign B.V., 06.2026
// SPI Slave — all-modes variant
//
// - SPI mode: 0, 1, 2 or 3, selected by the CPOL / CPHA input pins
//     CPOL = SCK idle level, CPHA = 0: sample on leading edge / drive on trailing edge
//                            CPHA = 1: drive on leading edge / sample on trailing edge
//   CPOL/CPHA are strap or GPIO-driven configuration inputs; they are captured
//   while the FSM is in IDLE, so they must be stable before SSEL is asserted.
// - Address byte: MSB is R/nW command bit (1=Read, 0=Write); lower 7 bits are register address (0x00–0x7F)
// - Register map: 8 × 8-bit registers at addresses 0x00–0x07; reads outside this range return 0xFF
// - Register width: 1 byte
// - Secondary parallel read port (Add2_in / Data2_out) allows concurrent register readback independent of SPI
// - SCK is oversampled by Clk (two-flip-flop synchroniser + edge detection):
//   keep SCK ≤ Clk/8 (e.g. 12.5 MHz SCK at 100 MHz Clk)

`define STATE_SPI_IDLE 		3'd0
`define STATE_SPI_COMMAND	3'd1
`define STATE_SPI_WRITE 	3'd2
`define STATE_SPI_READ 		3'd3
`define STATE_SPI_END 		3'd4

`define ERROR_ADD_OUT_OF_RANGE 	8'hFF

module spi_slave
(
	input Clk,          // system clock; all internal logic is synchronous to this
	input iRST_N,       // active-low asynchronous reset

	input CPOL,         // SPI mode select: SCK idle level (mode[1])
	input CPHA,         // SPI mode select: sample/drive edge choice (mode[0])

	input SCK,          // SPI clock from master
	input MOSI,         // master-out slave-in data
	input SSEL,         // SPI slave select, active low
	output reg MISO,    // master-in slave-out data

	input [7:0] Add2_in,        // parallel read port: register address
	output reg [7:0] Data2_out, // parallel read port: register data out (updated every Clk cycle)

	output reg [7:0] debug      // sticky OR of state-machine states visited since last reset
);

reg [7:0] Register0, Register1, Register2, Register3, Register4, Register5, Register6, Register7;

reg SCK_metastable, MOSI_metastable, SSEL_metastable, CPOL_metastable, CPHA_metastable;
reg SCK_delay0, MOSI_delay0, SSEL_delay0, CPOL_delay0, CPHA_delay0;
reg SCK_delay1, SSEL_delay1;
reg CPOL_latched, CPHA_latched;
reg WrEn, RnW;
reg [3:0] BitCnt;
reg [7:0] ReceivedByte, Data_fromSPI, DataToSend, Data_toSPI, Add_SPI;
reg [2:0] SPI_State;

// SCK normalised to look like mode-0 polarity: idle low, leading edge = rising
wire SCK_norm0 = SCK_delay0 ^ CPOL_latched;
wire SCK_norm1 = SCK_delay1 ^ CPOL_latched;
wire LeadingEdge  =  SCK_norm0 & ~SCK_norm1;
wire TrailingEdge = ~SCK_norm0 &  SCK_norm1;
wire SampleEdge = CPHA_latched ? TrailingEdge : LeadingEdge;  // master has data valid here
wire DriveEdge  = CPHA_latched ? LeadingEdge  : TrailingEdge; // slave updates MISO here

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
		CPOL_metastable <= 1'b0;
		CPHA_metastable <= 1'b0;
		SCK_delay0 	<= 1'b0;
		MOSI_delay0 	<= 1'b0;
		SSEL_delay0 	<= 1'b0;
		CPOL_delay0 	<= 1'b0;
		CPHA_delay0 	<= 1'b0;
		SCK_delay1 	<= 1'b0;
		SSEL_delay1 	<= 1'b0;
		CPOL_latched	<= 1'b0;
		CPHA_latched	<= 1'b0;
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
		// Two-stage synchroniser: captures async SPI inputs into Clk domain to prevent metastability
		SCK_metastable 	<= SCK;
		MOSI_metastable <= MOSI;
		SSEL_metastable <= SSEL;
		CPOL_metastable <= CPOL;
		CPHA_metastable <= CPHA;
		SCK_delay0 	<= SCK_metastable;
		MOSI_delay0 	<= MOSI_metastable;
		SSEL_delay0 	<= SSEL_metastable;
		CPOL_delay0 	<= CPOL_metastable;
		CPHA_delay0 	<= CPHA_metastable;
		SCK_delay1 	<= SCK_delay0;
		SSEL_delay1 	<= SSEL_delay0;

		WrEn 		<= 1'b0;

		case (SPI_State)

			`STATE_SPI_IDLE: begin
				BitCnt <= 0;
				// Mode pins are only taken over while idle so a transaction
				// always runs with a consistent CPOL/CPHA pair
				CPOL_latched <= CPOL_delay0;
				CPHA_latched <= CPHA_delay0;
				debug <= debug | 1;
				if (SSEL_delay0 == 0  && SSEL_delay1 == 1)
					SPI_State <= `STATE_SPI_COMMAND;
			end

			`STATE_SPI_COMMAND: begin
				debug <= debug | 8'h02;
				if (SampleEdge) begin
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
				if (SampleEdge) begin
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
					if (DriveEdge) begin
						MISO <= Data_toSPI[7];
						DataToSend <= {Data_toSPI[6:0], 1'b0};
						BitCnt <= 1;
					end
				end
				else begin
					if (DriveEdge) begin
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
