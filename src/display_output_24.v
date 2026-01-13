/**
 * 显示输出模块
 * 功能：时间拆分与显示驱动
 * 显示格式：HHMMSS（6位数码管）
 * 输入：二进制编码的时间（hour: 0-23, minute: 0-59, second: 0-59）
 * 数码管分配：
 *   LG1: 秒个位(S0) —— 使用七段译码器显示十进制0~9
 *   LG2: 秒十位(S1) —— 以二进制方式在4个段(A~D)上显示（0-5）
 *   LG3: 分个位(M0) —— 二进制显示（0-9）
 *   LG4: 分十位(M1) —— 二进制显示（0-5）
 *   LG5: 时个位(H0) —— 二进制显示（0-9）
 *   LG6: 时十位(H1) —— 二进制显示（0-2）
 */
module display_output_24 (
    input  wire [4:0] hour,      // 小时（二进制：0-23）
    input  wire [5:0] minute,    // 分钟（二进制：0-59）
    input  wire [5:0] second,    // 秒（二进制：0-59）
    output wire [7:0] lg1_seg,   // LG1段码输出（秒个位，含dp）
    output wire [3:0] lg2_seg,   // LG2段码输出（秒十位，A-D）
    output wire [3:0] lg3_seg,   // LG3段码输出（分个位，A-D）
    output wire [3:0] lg4_seg,   // LG4段码输出（分十位，A-D）
    output wire [3:0] lg5_seg,   // LG5段码输出（时个位，A-D）
    output wire [3:0] lg6_seg    // LG6段码输出（时十位，A-D）
);

    // 时间拆分：通过整除和求余得到各个位
    wire [3:0] second_ones;      // 秒个位（0-9）
    wire [3:0] second_tens;      // 秒十位（0-5）
    wire [3:0] minute_ones;       // 分个位（0-9）
    wire [3:0] minute_tens;       // 分十位（0-5）
    wire [3:0] hour_ones;         // 时个位（0-9）
    wire [3:0] hour_tens;         // 时十位（0-2）
    
    // 整除和求余运算
    assign second_ones = second % 10;      // 秒个位：0-9
    assign second_tens = second / 10;      // 秒十位：0-5
    assign minute_ones = minute % 10;     // 分个位：0-9
    assign minute_tens = minute / 10;      // 分十位：0-5
    assign hour_ones = hour % 10;          // 时个位：0-9
    assign hour_tens = hour / 10;          // 时十位：0-2
    
    // LG1: 秒个位，使用七段译码器显示十进制0~9
    wire [6:0] seg_s0;
    seg7_decoder u_seg_s0 (
        .bcd_in(second_ones),
        .seg_out(seg_s0)
    );
    
    // 输出分配
    // LG1: 秒个位，完整7段+小数点（D0-D7对应a,b,c,d,e,f,g,dp）
    assign lg1_seg[6:0] = seg_s0;
    assign lg1_seg[7]  = 1'b0;  // 小数点默认不亮
    
    // LG2: 秒十位（0-5，使用低3位，最高位补0）
    assign lg2_seg = {1'b0, second_tens[2:0]};
    
    // LG3: 分个位（0-9，使用完整的4位）
    assign lg3_seg = minute_ones[3:0];
    
    // LG4: 分十位（0-5，使用低3位，最高位补0）
    assign lg4_seg = {1'b0, minute_tens[2:0]};
    
    // LG5: 时个位（0-9，使用完整的4位）
    assign lg5_seg = hour_ones[3:0];
    
    // LG6: 时十位（0-2，使用低2位，高2位补0）
    assign lg6_seg = {2'b00, hour_tens[1:0]};

endmodule

