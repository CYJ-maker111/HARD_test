/**
 * 数字电子钟顶层模块
 * 功能：整合所有子模块，实现完整的数字电子钟系统
 * 平台：Altera EPM7128 / Xilinx Spartan-6
 */
module digital_clock_top (
    // 系统信号
    input  wire CLR_n,      // 复位信号（低有效，引脚1）
    input  wire MF,          // 主时钟（引脚55，备用）
    input  wire CP3,         // 1Hz时钟（引脚58，秒基准）
    
    // 控制信号
    input  wire K0,          // 校时使能（引脚54）
    input  wire K1,          // 小时调整选择（引脚81）
    input  wire K2,          // 分钟调整选择（引脚80）
    input  wire QD,          // 校时确认按钮（引脚60）
    
    // 显示输出 - LG1（秒个位，完整7段+dp）
    output wire LG1_D0,      // 引脚44
    output wire LG1_D1,      // 引脚45
    output wire LG1_D2,      // 引脚46
    output wire LG1_D3,      // 引脚48
    output wire LG1_D4,      // 引脚49
    output wire LG1_D5,      // 引脚50
    output wire LG1_D6,      // 引脚51
    output wire LG1_D7,      // 引脚52（小数点/SPEAKER）
    
    // 显示输出 - LG2（秒十位，A-D段）
    output wire LG2_A,       // 引脚37
    output wire LG2_B,       // 引脚39
    output wire LG2_C,       // 引脚40
    output wire LG2_D,       // 引脚41
    
    // 显示输出 - LG3（分个位，A-D段）
    output wire LG3_A,       // 引脚35
    output wire LG3_B,       // 引脚36
    output wire LG3_C,       // 引脚17
    output wire LG3_D,       // 引脚18
    
    // 显示输出 - LG4（分十位，A-D段）
    output wire LG4_A,       // 引脚30
    output wire LG4_B,       // 引脚31
    output wire LG4_C,       // 引脚33
    output wire LG4_D,       // 引脚34
    
    // 显示输出 - LG5（时个位，A-D段）
    output wire LG5_A,       // 引脚25
    output wire LG5_B,       // 引脚27
    output wire LG5_C,       // 引脚28
    output wire LG5_D,       // 引脚29
    
    // 显示输出 - LG6（时十位，A-D段）
    output wire LG6_A,       // 引脚20
    output wire LG6_B,       // 引脚21
    output wire LG6_C,       // 引脚22
    output wire LG6_D        // 引脚24
);

    // 内部信号
    wire clk_1hz;            // 1Hz时钟（使用CP3）
    wire rst_n;              // 复位信号（同步后）
    wire hour_en, min_en;    // 校时使能信号
    wire [4:0] hour;         // 小时（BCD）
    wire [6:0] minute;       // 分钟（BCD）
    wire [6:0] second;       // 秒（BCD）
    
    // 显示段码
    wire [7:0] lg1_seg;
    wire [3:0] lg2_seg, lg3_seg, lg4_seg, lg5_seg, lg6_seg;
    
    // 复位信号同步（异步复位，同步释放）
    reg rst_sync1, rst_sync2;
    always @(posedge CP3 or negedge CLR_n) begin
        if (!CLR_n) begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= 1'b0;
        end else begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= rst_sync1;
        end
    end
    assign rst_n = rst_sync2;
    assign clk_1hz = CP3;  // 直接使用外部1Hz时钟
    
    // 校时控制模块
    adjust_ctrl u_adjust_ctrl (
        .clk(CP3),
        .rst_n(rst_n),
        .K0(K0),
        .K1(K1),
        .K2(K2),
        .QD(QD),
        .hour_en(hour_en),
        .min_en(min_en)
    );
    
    // 时间计数模块
    time_counter u_time_counter (
        .clk_1hz(clk_1hz),
        .rst_n(rst_n),
        .hour_en(hour_en),
        .min_en(min_en),
        .hour(hour),
        .minute(minute),
        .second(second)
    );
    
    // 显示输出模块
    display_output u_display_output (
        .hour(hour),
        .minute(minute),
        .second(second),
        .lg1_seg(lg1_seg),
        .lg2_seg(lg2_seg),
        .lg3_seg(lg3_seg),
        .lg4_seg(lg4_seg),
        .lg5_seg(lg5_seg),
        .lg6_seg(lg6_seg)
    );
    
    // 输出分配
    assign LG1_D0 = lg1_seg[0];
    assign LG1_D1 = lg1_seg[1];
    assign LG1_D2 = lg1_seg[2];
    assign LG1_D3 = lg1_seg[3];
    assign LG1_D4 = lg1_seg[4];
    assign LG1_D5 = lg1_seg[5];
    assign LG1_D6 = lg1_seg[6];
    assign LG1_D7 = lg1_seg[7];
    
    assign LG2_A = lg2_seg[3];
    assign LG2_B = lg2_seg[2];
    assign LG2_C = lg2_seg[1];
    assign LG2_D = lg2_seg[0];
    
    assign LG3_A = lg3_seg[0];
    assign LG3_B = lg3_seg[1];
    assign LG3_C = lg3_seg[2];
    assign LG3_D = lg3_seg[3];
    
    assign LG4_A = lg4_seg[0];
    assign LG4_B = lg4_seg[1];
    assign LG4_C = lg4_seg[2];
    assign LG4_D = lg4_seg[3];
    
    assign LG5_A = lg5_seg[0];
    assign LG5_B = lg5_seg[1];
    assign LG5_C = lg5_seg[2];
    assign LG5_D = lg5_seg[3];
    
    assign LG6_A = lg6_seg[0];
    assign LG6_B = lg6_seg[1];
    assign LG6_C = lg6_seg[2];
    assign LG6_D = lg6_seg[3];

endmodule

