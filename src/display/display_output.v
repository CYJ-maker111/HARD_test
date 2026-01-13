/**
 * 显示输出模块
 * 功能：时间拆分与显示驱动
 * 显示格式：HHMMSS（6位数码管）
 * 数码管分配：
 *   LG1: 秒个位(S0) —— 使用七段译码器显示十进制0~9
 *   LG2: 秒十位(S1) —— 以二进制方式在4个段(A~D)上显示
 *   LG3: 分个位(M0) —— 二进制
 *   LG4: 分十位(M1) —— 二进制
 *   LG5: 时个位(H0) —— 二进制
 *   LG6: 时十位(H1) —— 二进制
 */
module display_output (
    input  wire [4:0] hour,      // 小时（BCD：十位[4:1]，个位[0]）
    input  wire [6:0] minute,    // 分钟（BCD：十位[6:4]，个位[3:0]）
    input  wire [6:0] second,    // 秒（BCD：十位[6:4]，个位[3:0]）
    output wire [7:0] lg1_seg,   // LG1段码输出（秒个位，含dp）
    output wire [3:0] lg2_seg,   // LG2段码输出（秒十位，A-D）
    output wire [3:0] lg3_seg,   // LG3段码输出（分个位，A-D）
    output wire [3:0] lg4_seg,   // LG4段码输出（分十位，A-D）
    output wire [3:0] lg5_seg,   // LG5段码输出（时个位，A-D）
    output wire [3:0] lg6_seg    // LG6段码输出（时十位，A-D）
);

    // 仅对“秒个位”使用七段译码器
    wire [6:0] seg_s0;
    seg7_decoder u_seg_s0 (
        .bcd_in(second[3:0]),   // 假定 second[3:0] 为秒个位的BCD码
        .seg_out(seg_s0)
    );
    
    // 输出分配
    // LG1: 秒个位，完整7段+小数点（D0-D7对应a,b,c,d,e,f,g,dp）
    assign lg1_seg[6:0] = seg_s0;
    assign lg1_seg[7]  = 1'b0;  // 小数点默认不亮
    
    // LG2-LG6: 只使用A-D段（对应a,b,c,d），直接输出“二进制位”
    // 这里将各时间字段的若干位直接映射到段A-D，用作二进制指示灯
    
    // LG2: 秒十位（使用second[6:4]的三位二进制，最高位补0）
    assign lg2_seg = {1'b0, second[6:4]};
    
    // LG3: 分钟个位（使用minute[3:0]的四位二进制）
    assign lg3_seg = minute[3:0];
    
    // LG4: 分钟十位（使用minute[6:4]三位二进制，最高位补0）
    assign lg4_seg = {1'b0, minute[6:4]};
    
    // LG5/LG6: 小时（hour为内部简化编码，这里仅作为二进制位直接显示）
    // 约定：LG5显示低4位，LG6显示最高位（其余补0）
    assign lg5_seg = hour[3:0];
    assign lg6_seg = {3'b000, hour[4]};

endmodule

