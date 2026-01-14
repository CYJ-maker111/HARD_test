module count(
    input clk,            // 外部 1Hz 脉冲（每秒一个上升沿）
    input set_clk,        // 校时模式切换键（上升沿有效）
    input set_hour,
    input set_min,
    input set_sec,
    input rst,
    input alarm_en,
    input [3:0] alarm_hour_tens,
    input [3:0] alarm_hour_units,
    input [3:0] alarm_min_tens,
    input [3:0] alarm_min_units,
    output [6:0] seg,
    output [3:0] sec,     // 秒个位 (0-9)
    output [3:0] thi,     // 秒十位 (0-5)
    output [3:0] fou,     // 分个位 (0-9)
    output [3:0] five,    // 分十位 (0-5)
    output [3:0] six,     // 时个位 (0-9) —— 注意：缺少时十位输出！
    output alarm
);

// 时间寄存器（按实际含义命名，但输出保持原名）
reg [3:0] sec_u; // 秒个位
reg [3:0] sec_t; // 秒十位
reg [3:0] min_u; // 分个位
reg [3:0] min_t; // 分十位
reg [3:0] hr_u;  // 时个位
reg [3:0] hr_t;  // 时十位

// 校时控制
reg set_clk_prev;
reg in_adjust; // 1 = 校时模式（暂停计时）

// 按键边沿检测
reg set_hour_prev, set_min_prev, set_sec_prev;

// 七段显示（显示秒个位，配合动态扫描）
reg [6:0] seg_out;

// 主时序逻辑
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        sec_u <= 0; sec_t <= 0;
        min_u <= 0; min_t <= 0;
        hr_u  <= 0; hr_t  <= 0;
        in_adjust <= 0;
        set_clk_prev <= 0;
        set_hour_prev <= 0;
        set_min_prev  <= 0;
        set_sec_prev  <= 0;
    end else begin
        // 更新按键历史（用于边沿检测）
        set_clk_prev <= set_clk;
        set_hour_prev <= set_hour;
        set_min_prev  <= set_min;
        set_sec_prev  <= set_sec;

        // 切换校时模式（set_clk 上升沿）
        if (set_clk && !set_clk_prev) begin
            in_adjust <= ~in_adjust;
        end

        if (in_adjust) begin
            // ========== 校时模式：暂停计时，仅响应按键 ==========
            // 校秒（加1秒）
            if (set_sec && !set_sec_prev) begin
                if (sec_u == 9) begin
                    sec_u <= 0;
                    if (sec_t == 5) begin
                        sec_t <= 0;
                    end else begin
                        sec_t <= sec_t + 1;
                    end
                end else begin
                    sec_u <= sec_u + 1;
                end
            end

            // 校分（加1分）
            if (set_min && !set_min_prev) begin
                if (min_u == 9) begin
                    min_u <= 0;
                    if (min_t == 5) begin
                        min_t <= 0;
                    end else begin
                        min_t <= min_t + 1;
                    end
                end else begin
                    min_u <= min_u + 1;
                end
            end

            // 校时（加1小时）
            if (set_hour && !set_hour_prev) begin
                if (hr_t == 2 && hr_u == 3) begin // 23 -> 00
                    hr_t <= 0;
                    hr_u <= 0;
                end else if (hr_u == 9) begin
                    hr_u <= 0;
                    hr_t <= hr_t + 1;
                end else begin
                    hr_u <= hr_u + 1;
                end
            end

        end else begin
            // ========== 正常计时模式 ==========
            // 秒加1
            if (sec_u == 9) begin
                sec_u <= 0;
                if (sec_t == 5) begin // 59秒 -> 00秒，进分钟
                    sec_t <= 0;
                    // 分加1
                    if (min_u == 9) begin
                        min_u <= 0;
                        if (min_t == 5) begin // 59分 -> 00分，进小时
                            min_t <= 0;
                            // 时加1
                            if (hr_t == 2 && hr_u == 3) begin // 23:59:59 -> 00:00:00
                                hr_t <= 0;
                                hr_u <= 0;
                            end else if (hr_u == 9) begin
                                hr_u <= 0;
                                hr_t <= hr_t + 1;
                            end else begin
                                hr_u <= hr_u + 1;
                            end
                        end else begin
                            min_t <= min_t + 1;
                        end
                    end else begin
                        min_u <= min_u + 1;
                    end
                end else begin
                    sec_t <= sec_t + 1;
                end
            end else begin
                sec_u <= sec_u + 1;
            end

        end
        // else: in_adjust=0 且 start=0 → 保持所有寄存器不变（暂停）
    end
end

// 七段译码（显示秒个位 sec_u）
always @(*) begin
    case (sec_u)
        4'd0: seg_out = 7'b0111111;
        4'd1: seg_out = 7'b0000110;
        4'd2: seg_out = 7'b1011011;
        4'd3: seg_out = 7'b1001111;
        4'd4: seg_out = 7'b1100110;
        4'd5: seg_out = 7'b1101101;
        4'd6: seg_out = 7'b1111101;
        4'd7: seg_out = 7'b0000111;
        4'd8: seg_out = 7'b1111111;
        4'd9: seg_out = 7'b1101111;
        default: seg_out = 7'b0000000;
    endcase
end

// 输出映射（按你原命名）
assign seg  = seg_out;
assign sec  = sec_u;   // 秒个位
assign thi  = sec_t;   // 秒十位
assign fou  = min_u;   // 分个位
assign five = min_t;   // 分十位
assign six  = hr_u;    // 时个位（注意：缺少 hr_t 输出！）

// 闹钟：当时间匹配且处于整秒（1Hz上升沿时刻即为整秒）
assign alarm = alarm_en &&
               (hr_t  == alarm_hour_tens) &&
               (hr_u  == alarm_hour_units) &&
               (min_t == alarm_min_tens)  &&
               (min_u == alarm_min_units) &&
               (sec_t == 0) &&
               (sec_u == 0);

endmodule