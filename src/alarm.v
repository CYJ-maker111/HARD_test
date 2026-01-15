module clock(
    input clk,           // 1000Hz 主时钟
    input set_clr,       // 设置当前时间模式（暂停计时）
    input set_clk,       // 设置加一（上升沿）
    input set_hour,
    input set_min,
    input set_sec,
    input rst,           // 异步复位（低电平有效）
    input set_alarm,     // 闹钟设置模式（高电平有效）
    input alarm_on_off,  // 闹钟开关（上升沿切换）
    output [6:0] seg,    // 七段数码管（正常：秒个位；闹钟设置：分个位）
    output [3:0] sec,    // 秒十位（闹钟模式固定为0）
    output [3:0] thi,    // 分个位
    output [3:0] four,   // 分十位
    output [3:0] five,   // 时个位
    output [3:0] six,    // 时十位
    output alarm_flag,
    output buzzer
);

// ---------------------- 寄存器定义 ----------------------
reg [3:0] cnt;           // 秒个位 (0-9)
reg [3:0] sec_cnt;       // 秒十位 (0-5)
reg [3:0] thi_cnt;       // 分个位 (0-9)
reg [3:0] four_cnt;      // 分十位 (0-5)
reg [3:0] five_cnt;      // 时个位 (0-9)
reg [3:0] six_cnt;       // 时十位 (0-2)

// 闹钟寄存器（HH:MM）
reg [3:0] alarm_thi_cnt;   // 闹钟分个位
reg [3:0] alarm_four_cnt;  // 闹钟分十位
reg [3:0] alarm_five_cnt;  // 闹钟时个位
reg [3:0] alarm_six_cnt;   // 闹钟时十位

// 简化分频器
reg [9:0] clk_div_cnt;
wire clk_1hz = (clk_div_cnt == 10'd999); // 1000Hz → 1Hz

// 简化同步逻辑 - 只同步关键信号
reg set_clk_sync, set_clk_prev;
wire set_clk_rise;

reg prev_alarm_on_off;
reg alarm_enabled;
reg alarm_triggered;

// 简化蜂鸣器控制
reg [8:0] buzzer_counter;  // 改为9位，用于500Hz分频
reg [5:0] alarm_duration_counter;  // 改为6位，用于60秒计数
reg buzzer_output;

// ---------------------- 输入同步（简化） ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        set_clk_sync <= 1'b0;
    end else begin
        set_clk_sync <= set_clk;
    end
end

// ---------------------- 上升沿检测 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst)
        set_clk_prev <= 1'b0;
    else
        set_clk_prev <= set_clk_sync;
end

assign set_clk_rise = set_clk_sync & ~set_clk_prev;

// ---------------------- 分频器 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst)
        clk_div_cnt <= 10'd0;
    else if (clk_div_cnt == 10'd999)
        clk_div_cnt <= 10'd0;
    else
        clk_div_cnt <= clk_div_cnt + 1'b1;
end

// ---------------------- 闹钟开关控制 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        prev_alarm_on_off <= 1'b0;
        alarm_enabled <= 1'b0;
    end else begin
        prev_alarm_on_off <= alarm_on_off;
        if (alarm_on_off & ~prev_alarm_on_off)
            alarm_enabled <= ~alarm_enabled;
    end
end

// ---------------------- 蜂鸣器控制（简单逻辑） ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        buzzer_counter <= 9'd0;
        buzzer_output <= 1'b0;
        alarm_duration_counter <= 6'd0;
        alarm_triggered <= 1'b0;
    end else begin
        // 闹钟触发检测（精确到分钟）
        if (clk_1hz) begin
            // 检查闹钟是否到达设定时间（只比较时和分）
            if (alarm_enabled && 
                thi_cnt == alarm_thi_cnt &&
                four_cnt == alarm_four_cnt &&
                five_cnt == alarm_five_cnt &&
                six_cnt == alarm_six_cnt) begin
                // 时分匹配时立即触发闹钟
                if (!alarm_triggered) begin
                    alarm_triggered <= 1'b1;
                    alarm_duration_counter <= 6'd0;  // 重置持续时间计数器
                end
            end
            
            // 闹钟持续时间控制（持续60秒）
            if (alarm_triggered) begin
                if (alarm_duration_counter < 6'd59) begin  // 0-59，共60秒
                    alarm_duration_counter <= alarm_duration_counter + 1'b1;
                end else begin
                    alarm_triggered <= 1'b0;  // 60秒后自动停止
                end
            end
        end
        
        // 蜂鸣器频率生成 - 产生500Hz方波
        buzzer_counter <= buzzer_counter + 1'b1;
        
        if (alarm_triggered) begin
            // 产生500Hz方波：1000Hz时钟，每2个时钟翻转一次
            // buzzer_counter从0计数到1，产生500Hz
            if (buzzer_counter[0]) begin  // 第0位翻转产生500Hz
                buzzer_output <= 1'b1;
            end else begin
                buzzer_output <= 1'b0;
            end
        end else begin
            buzzer_output <= 1'b0;
            buzzer_counter <= 9'd0;
        end
    end
end


// ---------------------- 时间主逻辑 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cnt <= 4'd0;
        sec_cnt <= 4'd0;
        thi_cnt <= 4'd0;
        four_cnt <= 4'd0;
        five_cnt <= 4'd0;
        six_cnt <= 4'd0;
    end else if (set_clk_rise && set_clr && !set_alarm) begin
        // ===== 设置当前时间（仅当 set_clr=1 且 set_alarm=0）=====
        // 简化：直接使用异步输入，不进行同步
        if (set_sec) begin
            if (cnt == 4'd9) begin
                cnt <= 4'd0;
                if (sec_cnt == 4'd5) sec_cnt <= 4'd0;
                else sec_cnt <= sec_cnt + 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end else if (set_min) begin
            if (thi_cnt == 4'd9) begin
                thi_cnt <= 4'd0;
                if (four_cnt == 4'd5) four_cnt <= 4'd0;
                else four_cnt <= four_cnt + 1'b1;
            end else begin
                thi_cnt <= thi_cnt + 1'b1;
            end
        end else if (set_hour) begin
            if (five_cnt == 4'd9) begin
                five_cnt <= 4'd0;
                if (six_cnt == 4'd2) six_cnt <= 4'd0;
                else six_cnt <= six_cnt + 1'b1;
            end else if (six_cnt == 4'd2 && five_cnt == 4'd3) begin
                five_cnt <= 4'd0;
                six_cnt <= 4'd0;
            end else begin
                five_cnt <= five_cnt + 1'b1;
            end
        end
    end else if (!set_clr && !set_alarm && clk_1hz) begin
        // ===== 正常计时（仅当非任何设置模式）=====
        if (cnt == 4'd9) begin
            cnt <= 4'd0;
            if (sec_cnt == 4'd5) begin
                sec_cnt <= 4'd0;
                if (thi_cnt == 4'd9) begin
                    thi_cnt <= 4'd0;
                    if (four_cnt == 4'd5) begin
                        four_cnt <= 4'd0;
                        if (six_cnt == 4'd2 && five_cnt == 4'd3) begin
                            five_cnt <= 4'd0;
                            six_cnt <= 4'd0;
                        end else if (five_cnt == 4'd9) begin
                            five_cnt <= 4'd0;
                            six_cnt <= six_cnt + 1'b1;
                        end else begin
                            five_cnt <= five_cnt + 1'b1;
                        end
                    end else begin
                        four_cnt <= four_cnt + 1'b1;
                    end
                end else begin
                    thi_cnt <= thi_cnt + 1'b1;
                end
            end else begin
                sec_cnt <= sec_cnt + 1'b1;
            end
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
    // 否则保持（包括 set_alarm=1 时）
end

// ---------------------- 闹钟设置逻辑 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        alarm_thi_cnt <= 4'd0;
        alarm_four_cnt <= 4'd0;
        alarm_five_cnt <= 4'd0;
        alarm_six_cnt <= 4'd0;
    end else if (set_clk_rise && set_alarm) begin
        // 注意：即使 set_clr=1，只要 set_alarm=1，就优先进入闹钟设置
        if (set_min) begin
            if (alarm_thi_cnt == 4'd9) begin
                alarm_thi_cnt <= 4'd0;
                if (alarm_four_cnt == 4'd5) alarm_four_cnt <= 4'd0;
                else alarm_four_cnt <= alarm_four_cnt + 1'b1;
            end else begin
                alarm_thi_cnt <= alarm_thi_cnt + 1'b1;
            end
        end else if (set_hour) begin
            if (alarm_five_cnt == 4'd9) begin
                alarm_five_cnt <= 4'd0;
                if (alarm_six_cnt == 4'd2) alarm_six_cnt <= 4'd0;
                else alarm_six_cnt <= alarm_six_cnt + 1'b1;
            end else if (alarm_six_cnt == 4'd2 && alarm_five_cnt == 4'd3) begin
                alarm_five_cnt <= 4'd0;
                alarm_six_cnt <= 4'd0;
            end else begin
                alarm_five_cnt <= alarm_five_cnt + 1'b1;
            end
        end
        // set_sec 被忽略
    end
end

// ---------------------- BCD 转七段译码 ----------------------
// 改为组合逻辑，节省寄存器资源
wire [6:0] seg_cnt = bcd_to_seg(cnt);
wire [6:0] seg_alarm_thi = bcd_to_seg(alarm_thi_cnt);

function [6:0] bcd_to_seg;
    input [3:0] bcd;
    case (bcd)
        4'd0: bcd_to_seg = 7'b0111111;
        4'd1: bcd_to_seg = 7'b0000110;
        4'd2: bcd_to_seg = 7'b1011011;
        4'd3: bcd_to_seg = 7'b1001111;
        4'd4: bcd_to_seg = 7'b1100110;
        4'd5: bcd_to_seg = 7'b1101101;
        4'd6: bcd_to_seg = 7'b1111101;
        4'd7: bcd_to_seg = 7'b0000111;
        4'd8: bcd_to_seg = 7'b1111111;
        4'd9: bcd_to_seg = 7'b1101111;
        default: bcd_to_seg = 7'b0000000;
    endcase
endfunction

// ---------------------- 输出 ----------------------
assign seg = set_alarm ? seg_alarm_thi : seg_cnt;
assign sec  = set_alarm ? 4'd0 : sec_cnt;
assign thi  = set_alarm ? alarm_thi_cnt : thi_cnt;
assign four = set_alarm ? alarm_four_cnt : four_cnt;
assign five = set_alarm ? alarm_five_cnt : five_cnt;
assign six  = set_alarm ? alarm_six_cnt : six_cnt;
assign alarm_flag = alarm_triggered;
assign buzzer = buzzer_output;

endmodule