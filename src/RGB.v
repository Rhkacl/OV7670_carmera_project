// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>

`timescale 1ns / 1ps

module RGB (
   input[11:0] Din,
   input Nblank,
   input reset,
   output [7:0] R, 
   output [7:0] G, 
   output [7:0] B,    
   output [7:0] Grayscale  
   );
//   assign R = (Nblank == 1'b1 && reset == 1'b0) ? {Din[11:8], Din[11:8]} : 8'b00000000 ;
 //  assign G = (Nblank == 1'b1 && reset == 1'b0) ? {Din[7:4], Din[7:4]} : 8'b00000000 ;
 //  assign B = (Nblank == 1'b1 && reset == 1'b0 ) ? {Din[3:0], Din[3:0]} : 8'b00000000 ;
    assign R = (Nblank && !reset) ? {Din[11:8], 4'b0000} : 8'b0; // 4→8비트 (상위 정렬)
    assign G = (Nblank && !reset) ? {Din[7:4],  4'b0000} : 8'b0;
    assign B = (Nblank && !reset) ? {Din[3:0],  4'b0000} : 8'b0;
   assign Grayscale = (Nblank == 1'b1 && reset == 1'b0 ) ? {16*(Din[11:8] + Din[7:4] + Din[3:0])/3} : 8'b00000000 ; 
    

    

endmodule
