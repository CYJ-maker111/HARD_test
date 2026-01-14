module clock(
    input clk,           // 1000Hz主时钟信号
    input set_clr,       // 开启：进入设置模式，计时暂停
    input set_clk,       // 按键：选中的数字加一
    input set_hour,      // 开启：选择设置小时模式，前提是进入设置模式
    input set_min,       // 开启：选择设置分钟模式，前提是进入设置模式
    input set_sec,       // 开启：选择设置秒模式，前提是进入设置模式
    input rst,           // 开启：复位，从零开始计时
    output [6:0] seg,    // 秒个位（七段数码管输出）
    output [3:0] sec,    // 秒十位
    output [3:0] thi,    // 分个位
    output [3:0] four,   // 分十位
    output [3:0] five,   // 时个位
    output [3:0] six     // 时十位
);

// 计数器定义
reg [3:0] cnt;        // 秒个位计数器
reg [3:0] sec_cnt;    // 秒十位计数器
reg [3:0] thi_cnt;    // 分个位计数器
reg [3:0] four_cnt;   // 分十位计数器
reg [3:0] five_cnt;   // 时个位计数器
reg [3:0] six_cnt;    // 时十位计数器

// 分频计数器（1000Hz -> 1Hz）
reg [9:0] clk_div_cnt; // 0~999计数，10位足够覆盖1000次
wire clk_1hz;          // 1Hz秒触发信号

// 按键检测相关
reg set_clk_prev;     // 用于检测set_clk的上升沿
wire set_clk_rise;    // set_clk上升沿信号

// ---------------------- 1. 1000Hz -> 1Hz 分频逻辑 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        clk_div_cnt <= 10'b0000000000;
    end else begin
        // 计数到999（1000次）后清零，生成1Hz脉冲
        if (clk_div_cnt == 10'b1111100111) begin // 999
            clk_div_cnt <= 10'b0000000000;
        end else begin
            clk_div_cnt <= clk_div_cnt + 10'b0000000001;
        end
    end
end
// 当分频计数器到999时，clk_1hz产生一个时钟周期的高电平（1ms）
assign clk_1hz = (clk_div_cnt == 10'b1111100111) ? 1'b1 : 1'b0;

// ---------------------- 2. set_clk按键上升沿检测（1000Hz采样） ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        set_clk_prev <= 1'b0;
    end else begin
        set_clk_prev <= set_clk;
    end
end
assign set_clk_rise = set_clk & ~set_clk_prev;

// ---------------------- 3. 复位和计时/设置模式逻辑 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        // 复位所有计数器
        cnt <= 4'b0000;
        sec_cnt <= 4'b0000;
        thi_cnt <= 4'b0000;
        four_cnt <= 4'b0000;
        five_cnt <= 4'b0000;
        six_cnt <= 4'b0000;
    end else if (set_clr) begin
        // 设置模式：按键触发时选中位加1（1000Hz检测按键，无延迟）
        if (set_clk_rise) begin
            if (set_hour) begin
                // 设置小时（24小时制边界处理）
                if (five_cnt == 4'b1001) begin
                    five_cnt <= 4'b0000;
                    if (six_cnt == 4'b0010) begin
                        six_cnt <= 4'b0000;
                    end else begin
                        six_cnt <= six_cnt + 4'b0001;
                    end
                end else if (six_cnt == 4'b0010 && five_cnt == 4'b0011) begin
                    // 23点后回到00点
                    five_cnt <= 4'b0000;
                    six_cnt <= 4'b0000;
                end else begin
                    five_cnt <= five_cnt + 4'b0001;
                end
            end else if (set_min) begin
                // 设置分钟（60分钟边界处理）
                if (thi_cnt == 4'b1001) begin
                    thi_cnt <= 4'b0000;
                    if (four_cnt == 4'b0101) begin
                        four_cnt <= 4'b0000;
                    end else begin
                        four_cnt <= four_cnt + 4'b0001;
                    end
                end else begin
                    thi_cnt <= thi_cnt + 4'b0001;
                end
            end else if (set_sec) begin
                // 设置秒（60秒边界处理）
                if (cnt == 4'b1001) begin
                    cnt <= 4'b0000;
                    if (sec_cnt == 4'b0101) begin
                        sec_cnt <= 4'b0000;
                    end else begin
                        sec_cnt <= sec_cnt + 4'b0001;
                    end
                end else begin
                    cnt <= cnt + 4'b0001;
                end
            end
        end
    end else begin
        // 正常计时模式：仅在1Hz秒脉冲触发时进位
        if (clk_1hz) begin
            // 秒个位计数（0~9）
            if (cnt == 4'b1001) begin
                cnt <= 4'b0000;
                // 秒十位计数（0~5）
                if (sec_cnt == 4'b0101) begin
                    sec_cnt <= 4'b0000;
                    // 分个位计数（0~9）
                    if (thi_cnt == 4'b1001) begin
                        thi_cnt <= 4'b0000;
                        // 分十位计数（0~5）
                        if (four_cnt == 4'b0101) begin
                            four_cnt <= 4'b0000;
                            // 时个位+时十位计数（24小时制）
                            if (six_cnt == 4'b0010 && five_cnt == 4'b0011) begin
                                // 23:59:59 -> 00:00:00
                                five_cnt <= 4'b0000;
                                six_cnt <= 4'b0000;
                            end else if (five_cnt == 4'b1001) begin
                                five_cnt <= 4'b0000;
                                six_cnt <= six_cnt + 4'b0001;
                            end else begin
                                five_cnt <= five_cnt + 4'b0001;
                            end
                        end else begin
                            four_cnt <= four_cnt + 4'b0001;
                        end
                    end else begin
                        thi_cnt <= thi_cnt + 4'b0001;
                    end
                end else begin
                    sec_cnt <= sec_cnt + 4'b0001;
                end
            end else begin
                cnt <= cnt + 4'b0001;
            end
        end
    end
end

// ---------------------- 4. 七段数码管译码器 ----------------------
reg [6:0] seg_out;
always @(*) begin
    case(cnt)
        4'b0000: seg_out = 7'b0111111;  // 显示数字0
        4'b0001: seg_out = 7'b0000110;  // 显示数字1
        4'b0010: seg_out = 7'b1011011;  // 显示数字2
        4'b0011: seg_out = 7'b1001111;  // 显示数字3
        4'b0100: seg_out = 7'b1100110;  // 显示数字4
        4'b0101: seg_out = 7'b1101101;  // 显示数字5
        4'b0110: seg_out = 7'b1111101;  // 显示数字6
        4'b0111: seg_out = 7'b0000111;  // 显示数字7
        4'b1000: seg_out = 7'b1111111;  // 显示数字8
        4'b1001: seg_out = 7'b1101111;  // 显示数字9
        default: seg_out = 7'b0000000; // 默认熄灭
    endcase
end

// 输出赋值
assign seg = seg_out;
assign sec = sec_cnt;
assign thi = thi_cnt;
assign four = four_cnt;
assign five = five_cnt;
assign six = six_cnt;

endmodule