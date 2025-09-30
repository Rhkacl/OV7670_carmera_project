// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>


`timescale 1 ns / 1 ps



module resetlocked (
  
    input pclk,
    input locked,
    output reset
    );
              
    reg [3:0] safestart;
    reg [3:0] safestart_nxt;

always @(*) begin

safestart_nxt =  {safestart[2:0], !locked};

   
end 
 
assign reset = safestart[3];
always @(posedge pclk or negedge locked) begin

if(!locked) begin
    
 safestart <=4'b1111;

    
end   

else begin
   safestart<= safestart_nxt;
end

end
   
endmodule
