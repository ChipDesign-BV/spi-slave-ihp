// Map Yosys' internal async-reset flip-flops onto sg13g2_hv_sdfbbp_1.
//
// sg13g2_hv_sdfbbp_1 is the only flip-flop in sg13g2_stdcell_hv that has
// layout. It is a scan flip-flop with both an async clear and an async
// preset, and its liberty next_state is the scan mux
//
//     next = (SCE & SCD) | (!SCE & D)
//
// which dfflibmap cannot invert, so the library needs an explicit mapping.
// The four flip-flop flavours the SPI slave produces are all covered:
//
//   $_DFF_PN0_    async reset to 0   -> RESET_B = R, SET_B = 1
//   $_DFF_PN1_    async reset to 1   -> SET_B   = R, RESET_B = 1
//   $_DFFE_PN0P_  + active-high CE   -> as above, plus the scan mux used as
//   $_DFFE_PN1P_  + active-high CE      the enable mux: SCE = !E, SCD = Q
//
// Using the scan mux as the clock-enable mux is what keeps the enabled
// flip-flops at one cell each; the alternative is an external feedback mux
// per flip-flop. Q -> SCD is a same-register feedback path, broken by the
// flip-flop itself, so it is a normal reg-to-reg path for STA.

module \$_DFF_PN0_ (input D, input C, input R, output Q);
  sg13g2_hv_sdfbbp_1 _TECHMAP_REPLACE_ (
      .D(D), .CLK(C), .RESET_B(R), .SET_B(1'b1),
      .SCE(1'b0), .SCD(1'b0), .Q(Q));
endmodule

module \$_DFF_PN1_ (input D, input C, input R, output Q);
  sg13g2_hv_sdfbbp_1 _TECHMAP_REPLACE_ (
      .D(D), .CLK(C), .RESET_B(1'b1), .SET_B(R),
      .SCE(1'b0), .SCD(1'b0), .Q(Q));
endmodule

module \$_DFFE_PN0P_ (input D, input C, input E, input R, output Q);
  wire ce_n;
  \$_NOT_ ce_inv (.A(E), .Y(ce_n));
  sg13g2_hv_sdfbbp_1 _TECHMAP_REPLACE_ (
      .D(D), .CLK(C), .RESET_B(R), .SET_B(1'b1),
      .SCE(ce_n), .SCD(Q), .Q(Q));
endmodule

module \$_DFFE_PN1P_ (input D, input C, input E, input R, output Q);
  wire ce_n;
  \$_NOT_ ce_inv (.A(E), .Y(ce_n));
  sg13g2_hv_sdfbbp_1 _TECHMAP_REPLACE_ (
      .D(D), .CLK(C), .RESET_B(1'b1), .SET_B(R),
      .SCE(ce_n), .SCD(Q), .Q(Q));
endmodule
