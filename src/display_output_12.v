/**
 * 显示输出模块（12 小时制）
 * 功能：时间拆分与显示驱动
 * 显示格式：HHMMSS（6位数码管），并用秒个位的小数点表示 AM/PM
 * 输入：二进制编码的时间（hour: 0-23, minute: 0-59, second: 0-59）
 * 数码管分配：
 *   LG1: 秒个位(S0) —— 使用七段译码器显示十进制0~9，dp 作为 AM/PM 指示
 *        上午：dp=0；下午：dp=1
 *   LG2: 秒十位(S1) —— 二进制显示（0-5）
 *   LG3: 分个位(M0) —— 二进制显示（0-9）
 *   LG4: 分十位(M1) —— 二进制显示（0-5）
 *   LG5: 时个位(H0) —— 二进制显示（1-12 的个位）
 *   LG6: 时十位(H1) —— 二进制显示（0-1，用来表示 1~12 的十位）
 */
module display_output_12 (
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

    // 24 小时计数转为 12 小时显示：
    // 00:xx -> 12:xx AM
    // 01~11 -> 1~11 AM
    // 12:xx -> 12:xx PM
    // 13~23 -> 1~11 PM
    wire [4:0] hour_12;   // 1~12
    wire       pm;        // 下午标志：1 表示下午 (PM)，0 表示上午 (AM)

    assign pm = (hour >= 5'd12);  // 12:00 及之后视为 PM

    assign hour_12 = (hour <= 5'd12) ? hour : (hour - 5'd12);

    // 时间拆分：通过整除和求余得到各个位
    wire [3:0] second_ones;      // 秒个位（0-9）
    wire [3:0] second_tens;      // 秒十位（0-5）
    wire [3:0] minute_ones;      // 分个位（0-9）
    wire [3:0] minute_tens;      // 分十位（0-5）
    wire [3:0] hour_ones;        // 时个位（1-12 的个位）
    wire [3:0] hour_tens;        // 时十位（0-1）
    
    // 整除和求余运算
    assign second_ones = second % 10;      // 秒个位：0-9
    assign second_tens = second / 10;      // 秒十位：0-5
    assign minute_ones = minute % 10;      // 分个位：0-9
    assign minute_tens = minute / 10;      // 分十位：0-5
    assign hour_ones   = hour_12 % 10;     // 时个位：0-9（但有效范围 1-9 或 0-2）
    assign hour_tens   = hour_12 / 10;     // 时十位：0-1
    
    // LG1: 秒个位，使用七段译码器显示十进制0~9
    wire [6:0] seg_s0;
    seg7_decoder u_seg_s0 (
        .bcd_in(second_ones),
        .seg_out(seg_s0)
    );
    
    // 输出分配
    // LG1: 秒个位，完整7段+小数点（D0-D7对应a,b,c,d,e,f,g,dp）
    // 小数点 dp 用于表示 AM/PM：AM=0，PM=1
    assign lg1_seg[6:0] = seg_s0;
    assign lg1_seg[7]  = pm;  // 下午亮起小数点，上午不亮
    
    // LG2: 秒十位（0-5，使用低3位，最高位补0）
    assign lg2_seg = {1'b0, second_tens[2:0]};
    
    // LG3: 分个位（0-9，使用完整的4位）
    assign lg3_seg = minute_ones[3:0];
    
    // LG4: 分十位（0-5，使用低3位，最高位补0）
    assign lg4_seg = {1'b0, minute_tens[2:0]};
    
    // LG5: 时个位（使用完整的4位，表示 1~12 的个位）
    assign lg5_seg = hour_ones[3:0];
    
    // LG6: 时十位（0-1，使用低2位，高2位补0）
    assign lg6_seg = {2'b00, hour_tens[1:0]};

endmodule

