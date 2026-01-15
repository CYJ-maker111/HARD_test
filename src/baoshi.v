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

// 简化同步逻辑 - 只同步一个关键信号
reg set_clk_prev;
wire set_clk_rise;

// 闹钟开关控制相关
reg alarm_on_off_prev;    // 用于边沿检测
reg alarm_enabled;        // 闹钟使能状态
reg alarm_active;         // 闹钟正在响

// ================== 极简2音符旋律 ==================
// 使用系统时钟的第0位和第1位产生两个频率
// 状态0: 500Hz (使用clk_div_cnt[0])
// 状态1: 250Hz (使用clk_div_cnt[1])
reg melody_state;         // 1位状态，0或1
reg [1:0] beep_counter;   // 2位计数器，用于0.5秒计数
reg [4:0] alarm_duration; // 闹钟持续时间计数器（最大31秒）

// ================== 整点报时相关 ==================
reg hourly_beep_active;   // 整点报时正在响
reg hourly_beep_done;     // 防止同一整点重复报时
wire is_hourly;           // 整点判断信号

// ================== 输入同步 ==================
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        set_clk_prev <= 1'b0;
        alarm_on_off_prev <= 1'b0;
    end else begin
        set_clk_prev <= set_clk;
        alarm_on_off_prev <= alarm_on_off;
    end
end

assign set_clk_rise = set_clk & ~set_clk_prev;
wire alarm_on_off_rise = alarm_on_off & ~alarm_on_off_prev;  // 上升沿检测

// ================== 分频器 ==================
always @(posedge clk or negedge rst) begin
    if (!rst)
        clk_div_cnt <= 10'd0;
    else if (clk_div_cnt == 10'd999)
        clk_div_cnt <= 10'd0;
    else
        clk_div_cnt <= clk_div_cnt + 1'b1;
end

// ================== 整点判断逻辑 ==================
// 整点条件：分钟为00，秒钟为00
assign is_hourly = (thi_cnt == 4'd0) && (four_cnt == 4'd0) && 
                   (cnt == 4'd0) && (sec_cnt == 4'd0);

// ================== 闹钟开关控制 ==================
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        alarm_enabled <= 1'b0;
        alarm_active <= 1'b0;
        melody_state <= 1'b0;
        beep_counter <= 2'b00;
        alarm_duration <= 5'd0;
        hourly_beep_active <= 1'b0;
        hourly_beep_done <= 1'b0;
    end else begin
        // 检测alarm_on_off的上升沿，反转alarm_enabled
        if (alarm_on_off_rise) begin
            alarm_enabled <= ~alarm_enabled;
        end
        
        // 检查时间是否匹配闹钟设置（精确到分钟）
        if (thi_cnt == alarm_thi_cnt &&
            four_cnt == alarm_four_cnt &&
            five_cnt == alarm_five_cnt &&
            six_cnt == alarm_six_cnt) begin
            // 当前时间与闹钟设置匹配
            
            // 如果闹钟使能，开始或继续闹钟
            if (alarm_enabled) begin
                alarm_active <= 1'b1;
                alarm_duration <= 5'd0;  // 重置持续时间
            end else begin
                // 闹钟使能关闭，停止闹钟
                alarm_active <= 1'b0;
                melody_state <= 1'b0;
                beep_counter <= 2'b00;
            end
        end else begin
            // 时间不匹配，检查是否需要自动停止
            if (alarm_active) begin
                // 闹钟已经在响，但时间已经过去
                if (alarm_duration < 5'd30) begin  // 继续响30秒
                    alarm_duration <= alarm_duration + 1'b1;
                end else begin
                    // 30秒后自动停止
                    alarm_active <= 1'b0;
                    melody_state <= 1'b0;
                    beep_counter <= 2'b00;
                    alarm_duration <= 5'd0;
                end
            end
        end
        
        // 如果闹钟正在响，更新旋律状态
        if (alarm_active) begin
            if (clk_1hz) begin
                beep_counter <= beep_counter + 1'b1;
                if (beep_counter == 2'b10) begin  // 每2秒切换一次状态
                    melody_state <= ~melody_state;
                    beep_counter <= 2'b00;
                end
            end
        end else begin
            // 闹钟停止，重置状态
            melody_state <= 1'b0;
            beep_counter <= 2'b00;
        end
        
        // ================== 整点报时控制 ==================
        // 在每个整点开始时触发报时
        if (is_hourly && clk_1hz) begin
            if (!hourly_beep_done) begin
                // 开始整点报时
                hourly_beep_active <= 1'b1;
                hourly_beep_done <= 1'b1;  // 标记已经报时过
            end
        end else if (!is_hourly) begin
            // 不在整点，重置标记
            hourly_beep_done <= 1'b0;
        end
        
        // 整点报时持续1秒
        if (hourly_beep_active) begin
            if (clk_1hz) begin
                // 1秒后停止整点报时
                hourly_beep_active <= 1'b0;
            end
        end
    end
end

// 蜂鸣器输出 - 组合逻辑
// 闹钟蜂鸣器和整点报时蜂鸣器使用或逻辑合并
wire alarm_buzzer = alarm_active ? 
                    (melody_state ? clk_div_cnt[1] : clk_div_cnt[0]) : 
                    1'b0;
                    
wire hourly_buzzer = hourly_beep_active ? clk_div_cnt[0] : 1'b0;  // 整点报时使用500Hz固定频率

assign buzzer = alarm_buzzer | hourly_buzzer;  // 合并两个蜂鸣器输出

// ================== 时间主逻辑 ==================
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        cnt <= 4'd0;
        sec_cnt <= 4'd0;
        thi_cnt <= 4'd0;
        four_cnt <= 4'd0;
        five_cnt <= 4'd0;
        six_cnt <= 4'd0;
    end else if (set_clk_rise && set_clr && !set_alarm) begin
        // 设置当前时间
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
        // 正常计时
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
end

// ================== 闹钟设置逻辑 ==================
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        alarm_thi_cnt <= 4'd0;
        alarm_four_cnt <= 4'd0;
        alarm_five_cnt <= 4'd0;
        alarm_six_cnt <= 4'd0;
    end else if (set_clk_rise && set_alarm) begin
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
    end
end

// ================== BCD 转七段译码 ==================
reg [6:0] seg_cnt;
always @(*) begin
    case (cnt)
        4'd0: seg_cnt = 7'b0111111;
        4'd1: seg_cnt = 7'b0000110;
        4'd2: seg_cnt = 7'b1011011;
        4'd3: seg_cnt = 7'b1001111;
        4'd4: seg_cnt = 7'b1100110;
        4'd5: seg_cnt = 7'b1101101;
        4'd6: seg_cnt = 7'b1111101;
        4'd7: seg_cnt = 7'b0000111;
        4'd8: seg_cnt = 7'b1111111;
        4'd9: seg_cnt = 7'b1101111;
        default: seg_cnt = 7'b0000000;
    endcase
end

reg [6:0] seg_alarm_thi;
always @(*) begin
    case (alarm_thi_cnt)
        4'd0: seg_alarm_thi = 7'b0111111;
        4'd1: seg_alarm_thi = 7'b0000110;
        4'd2: seg_alarm_thi = 7'b1011011;
        4'd3: seg_alarm_thi = 7'b1001111;
        4'd4: seg_alarm_thi = 7'b1100110;
        4'd5: seg_alarm_thi = 7'b1101101;
        4'd6: seg_alarm_thi = 7'b1111101;
        4'd7: seg_alarm_thi = 7'b0000111;
        4'd8: seg_alarm_thi = 7'b1111111;
        4'd9: seg_alarm_thi = 7'b1101111;
        default: seg_alarm_thi = 7'b0000000;
    endcase
end

// ================== 输出 ==================
assign seg = set_alarm ? seg_alarm_thi : seg_cnt;
assign sec  = set_alarm ? 4'd0 : sec_cnt;
assign thi  = set_alarm ? alarm_thi_cnt : thi_cnt;
assign four = set_alarm ? alarm_four_cnt : four_cnt;
assign five = set_alarm ? alarm_five_cnt : five_cnt;
assign six  = set_alarm ? alarm_six_cnt : six_cnt;
assign alarm_flag = alarm_active | hourly_beep_active;  // 闹钟标志包括整点报时

endmodule