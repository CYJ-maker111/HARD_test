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

// 时间常量定义（提升可读性）
localparam MAX_SEC_ONES  = 4'b1001; // 秒个位最大值9
localparam MAX_SEC_TENS  = 4'b0101; // 秒十位最大值5
localparam MAX_MIN_ONES  = 4'b1001; // 分个位最大值9
localparam MAX_MIN_TENS  = 4'b0101; // 分十位最大值5
localparam MAX_HOUR_ONES = 4'b1001; // 时个位最大值9
localparam MAX_HOUR_TENS = 4'b0010; // 时十位最大值2
localparam HOUR_23_ONES  = 4'b0011; // 23时的个位3

// 辅助变量：将设置模式的选择信号转为单值（适配case）
reg [1:0] set_mode;
always @(*) begin
    if (set_sec)      set_mode = 2'b01; // 设置秒
    else if (set_min) set_mode = 2'b10; // 设置分
    else if (set_hour)set_mode = 2'b11; // 设置时
    else              set_mode = 2'b00; // 无选择
end

// ---------------------- 1. 1000Hz -> 1Hz 分频逻辑 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        clk_div_cnt <= 10'b0000000000;
    end else begin
        if (clk_div_cnt == 10'b1111100111) begin // 999
            clk_div_cnt <= 10'b0000000000;
        end else begin
            clk_div_cnt <= clk_div_cnt + 10'b0000000001;
        end
    end
end
assign clk_1hz = (clk_div_cnt == 10'b1111100111) ? 1'b1 : 1'b0;

// ---------------------- 2. set_clk按键上升沿检测 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        set_clk_prev <= 1'b0;
    end else begin
        set_clk_prev <= set_clk;
    end
end
assign set_clk_rise = set_clk & ~set_clk_prev;

// ---------------------- 3. 主计时/设置逻辑（修复23:59:59进位） ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        // 复位所有计数器
        cnt <= 4'b0000;
        sec_cnt <= 4'b0000;
        thi_cnt <= 4'b0000;
        four_cnt <= 4'b0000;
        five_cnt <= 4'b0000;
        six_cnt <= 4'b0000;
    end 
    // 模式1：设置模式（按键调整时间，用case替代if-else if）
    else if (set_clr && set_clk_rise) begin
        case(set_mode)
            2'b01: begin // 设置秒
                if (cnt == MAX_SEC_ONES) begin
                    cnt <= 4'b0000;
                    sec_cnt <= (sec_cnt == MAX_SEC_TENS) ? 4'b0000 : (sec_cnt + 4'b0001);
                end else begin
                    cnt <= cnt + 4'b0001;
                end
            end
            2'b10: begin // 设置分
                if (thi_cnt == MAX_MIN_ONES) begin
                    thi_cnt <= 4'b0000;
                    four_cnt <= (four_cnt == MAX_MIN_TENS) ? 4'b0000 : (four_cnt + 4'b0001);
                end else begin
                    thi_cnt <= thi_cnt + 4'b0001;
                end
            end
            2'b11: begin // 设置时
                if (six_cnt == MAX_HOUR_TENS && five_cnt == HOUR_23_ONES) begin
                    five_cnt <= 4'b0000;
                    six_cnt <= 4'b0000;
                end else if (five_cnt == MAX_HOUR_ONES) begin
                    five_cnt <= 4'b0000;
                    six_cnt <= six_cnt + 4'b0001;
                end else begin
                    five_cnt <= five_cnt + 4'b0001;
                end
            end
            default: ; // 无选择，不操作
        endcase
    end
    // 模式2：正常计时模式（关键修复：调整时逻辑判断顺序）
    else if (!set_clr && clk_1hz) begin
        // ---------------------- 秒、分进位逻辑（原逻辑不变） ----------------------
        // 步骤1：秒个位进位（9→0）
        if (cnt == MAX_SEC_ONES) begin
            cnt <= 4'b0000;
        end else begin
            cnt <= cnt + 4'b0001;
        end
        // 步骤2：秒十位进位（59秒→0秒）
        if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS) begin
            sec_cnt <= 4'b0000;
        end else if (cnt == MAX_SEC_ONES) begin
            sec_cnt <= sec_cnt + 4'b0001;
        end
        // 步骤3：分个位进位（59秒→分+1，9→0）
        if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS && thi_cnt == MAX_MIN_ONES) begin
            thi_cnt <= 4'b0000;
        end else if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS) begin
            thi_cnt <= thi_cnt + 4'b0001;
        end
        // 步骤4：分十位进位（59分→0分）
        if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS && thi_cnt == MAX_MIN_ONES && four_cnt == MAX_MIN_TENS) begin
            four_cnt <= 4'b0000;
        end else if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS && thi_cnt == MAX_MIN_ONES) begin
            four_cnt <= four_cnt + 4'b0001;
        end

        // ---------------------- 时进位逻辑（核心修复：调整判断顺序） ----------------------
        // 【优先级最高】步骤5：23:59:59 → 00:00:00 全局清零
        if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS && thi_cnt == MAX_MIN_ONES && four_cnt == MAX_MIN_TENS 
            && six_cnt == MAX_HOUR_TENS && five_cnt == HOUR_23_ONES) begin
            five_cnt <= 4'b0000;
            six_cnt <= 4'b0000;
        end
        // 步骤6：时个位到9，时十位加1（如 09:59:59 → 10:00:00）
        else if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS && thi_cnt == MAX_MIN_ONES && four_cnt == MAX_MIN_TENS 
                && five_cnt == MAX_HOUR_ONES) begin
            five_cnt <= 4'b0000;
            six_cnt <= six_cnt + 4'b0001;
        end
        // 步骤7：普通情况，时个位加1（如 12:59:59 → 13:00:00）
        else if (cnt == MAX_SEC_ONES && sec_cnt == MAX_SEC_TENS && thi_cnt == MAX_MIN_ONES && four_cnt == MAX_MIN_TENS) begin
            five_cnt <= five_cnt + 4'b0001;
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