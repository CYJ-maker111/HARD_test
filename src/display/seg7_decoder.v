/**
 * 七段译码器模块
 * 功能：将4位BCD码转换为7段数码管驱动信号
 * 显示类型：共阴极数码管（低电平点亮）
 * 段码顺序：a, b, c, d, e, f, g (seg[6:0])
 */
module seg7_decoder (
    input  wire [3:0] bcd_in,  // BCD输入（0-9）
    output reg  [6:0] seg_out   // 7段输出（a-g）
);

    always @(*) begin
        case (bcd_in)
            4'd0: seg_out = 7'b0111111;  // 0: a,b,c,d,e,f亮
            4'd1: seg_out = 7'b0000110;  // 1: b,c亮
            4'd2: seg_out = 7'b1011011;  // 2: a,b,d,e,g亮
            4'd3: seg_out = 7'b1001111;  // 3: a,b,c,d,g亮
            4'd4: seg_out = 7'b1100110;  // 4: b,c,f,g亮
            4'd5: seg_out = 7'b1101101;  // 5: a,c,d,f,g亮
            4'd6: seg_out = 7'b1111101;  // 6: a,c,d,e,f,g亮
            4'd7: seg_out = 7'b0000111;  // 7: a,b,c亮
            4'd8: seg_out = 7'b1111111;  // 8: 全亮
            4'd9: seg_out = 7'b1101111;  // 9: a,b,c,d,f,g亮
            default: seg_out = 7'b0000000;  // 其他：全灭
        endcase
    end

endmodule

