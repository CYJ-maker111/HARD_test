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

reg [9:0] clk_div_cnt;
wire clk_1hz = (clk_div_cnt == 10'd999); // 1000Hz → 1Hz

// 同步输入（防亚稳态，可选但推荐）
reg set_clk_sync, set_clk_prev;
reg set_alarm_sync, set_clr_sync;
reg set_hour_sync, set_min_sync, set_sec_sync;

wire set_clk_rise;

reg prev_alarm_on_off;
reg alarm_enabled;
reg alarm_triggered;

reg [23:0] buzzer_counter;
reg [2:0]  alarm_duration_counter;
reg        buzzer_output;

// ---------------------- 输入同步 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        set_clk_sync <= 1'b0;
        set_alarm_sync <= 1'b0;
        set_clr_sync <= 1'b0;
        set_hour_sync <= 1'b0;
        set_min_sync <= 1'b0;
        set_sec_sync <= 1'b0;
    end else begin
        set_clk_sync <= set_clk;
        set_alarm_sync <= set_alarm;
        set_clr_sync <= set_clr;
        set_hour_sync <= set_hour;
        set_min_sync <= set_min;
        set_sec_sync <= set_sec;
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

/*
// ---------------------- 蜂鸣器控制 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        buzzer_counter <= 24'd0;
        buzzer_output <= 1'b0;
        alarm_duration_counter <= 3'd0;
    end else begin
        buzzer_counter <= buzzer_counter + 1'b1;
        if (alarm_triggered) begin
            if (buzzer_counter[18]) begin
                buzzer_output <= ～buzzer_output;
                if (alarm_duration_counter < 3'd7)
                    alarm_duration_counter <= alarm_duration_counter + 1'b1;
            end
        end else begin
            buzzer_output <= 1'b0;
            alarm_duration_counter <= 3'd0;
        end
        if (alarm_duration_counter == 3'd7)
            buzzer_output <= 1'b0;
    end
end
*/

// ---------------------- 闹钟触发检测 ----------------------
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        alarm_triggered <= 1'b0;
    end else if (clk_1hz) begin
        if (alarm_enabled &&
            thi_cnt == alarm_thi_cnt &&
            four_cnt == alarm_four_cnt &&
            five_cnt == alarm_five_cnt &&
            six_cnt == alarm_six_cnt)
            alarm_triggered <= 1'b1;
        else
            alarm_triggered <= 1'b0;
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
    end else if (set_clk_rise && set_clr_sync && !set_alarm_sync) begin
        // ===== 设置当前时间（仅当 set_clr=1 且 set_alarm=0）=====
        if (set_sec_sync) begin
            if (cnt == 4'd9) begin
                cnt <= 4'd0;
                if (sec_cnt == 4'd5) sec_cnt <= 4'd0;
                else sec_cnt <= sec_cnt + 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end else if (set_min_sync) begin
            if (thi_cnt == 4'd9) begin
                thi_cnt <= 4'd0;
                if (four_cnt == 4'd5) four_cnt <= 4'd0;
                else four_cnt <= four_cnt + 1'b1;
            end else begin
                thi_cnt <= thi_cnt + 1'b1;
            end
        end else if (set_hour_sync) begin
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
    end else if (!set_clr_sync && !set_alarm_sync && clk_1hz) begin
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
    end else if (set_clk_rise && set_alarm_sync) begin
        // 注意：即使 set_clr=1，只要 set_alarm=1，就优先进入闹钟设置
        if (set_min_sync) begin
            if (alarm_thi_cnt == 4'd9) begin
                alarm_thi_cnt <= 4'd0;
                if (alarm_four_cnt == 4'd5) alarm_four_cnt <= 4'd0;
                else alarm_four_cnt <= alarm_four_cnt + 1'b1;
            end else begin
                alarm_thi_cnt <= alarm_thi_cnt + 1'b1;
            end
        end else if (set_hour_sync) begin
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
        // set_sec_sync 被忽略
    end
end

// ---------------------- BCD 转七段译码 ----------------------
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
// 当闹钟触发时，seg 全亮（7'b1111111）
// 否则：闹钟设置模式显示 alarm_thi_cnt，正常模式显示 cnt
assign seg = alarm_triggered ? 7'b1111111 :
             (set_alarm_sync ? bcd_to_seg(alarm_thi_cnt) : bcd_to_seg(cnt));

assign sec  = set_alarm_sync ? 4'd0 : sec_cnt;
assign thi  = set_alarm_sync ? alarm_thi_cnt : thi_cnt;
assign four = set_alarm_sync ? alarm_four_cnt : four_cnt;
assign five = set_alarm_sync ? alarm_five_cnt : five_cnt;
assign six  = set_alarm_sync ? alarm_six_cnt : six_cnt;
assign alarm_flag = alarm_triggered;
assign buzzer = buzzer_output;

endmodule