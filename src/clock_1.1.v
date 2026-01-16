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
wire clk_1hz = (clk_div_cnt == 10'b1111100111); // 1000Hz → 1Hz

// 简化同步逻辑 - 只同步一个关键信号
reg set_clk_prev;
wire set_clk_rise;

// 闹钟开关控制相关
reg alarm_on_off_sync;    // 同步后的闹钟开关信号
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
        alarm_on_off_sync <= 1'b0;
    end else begin
        set_clk_prev <= set_clk;
        alarm_on_off_sync <= alarm_on_off;  // 直接同步输入信号
    end
end

assign set_clk_rise = set_clk & ~set_clk_prev;

// ================== 分频器 ==================
always @(posedge clk or negedge rst) begin
    if (!rst)
        clk_div_cnt <= 10'b0000000000;
    else if (clk_div_cnt == 10'b1111100111)
        clk_div_cnt <= 10'b0000000000;
    else
        clk_div_cnt <= clk_div_cnt + 1'b1;
end

// ================== 整点判断逻辑 ==================
// 整点条件：分钟为00，秒钟为00
assign is_hourly = (thi_cnt == 4'b0000) && (four_cnt == 4'b0000) && 
                   (cnt == 4'b0000) && (sec_cnt == 4'b0000);

// ================== 闹钟开关控制 ==================
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        alarm_active <= 1'b0;
        melody_state <= 1'b0;
        beep_counter <= 2'b00;
        alarm_duration <= 5'b00000;
        hourly_beep_active <= 1'b0;
        hourly_beep_done <= 1'b0;
    end else begin
        // 检查时间是否匹配闹钟设置（精确到分钟）
        if (thi_cnt == alarm_thi_cnt &&
            four_cnt == alarm_four_cnt &&
            five_cnt == alarm_five_cnt &&
            six_cnt == alarm_six_cnt) begin
            // 当前时间与闹钟设置匹配
            
            // 如果闹钟开关打开，开始或继续闹钟
            if (alarm_on_off_sync) begin
                alarm_active <= 1'b1;
                alarm_duration <= 5'b00000;  // 重置持续时间
            end else begin
                // 闹钟开关关闭，停止闹钟
                alarm_active <= 1'b0;
                melody_state <= 1'b0;
                beep_counter <= 2'b00;
            end
        end else begin
            // 时间不匹配，检查是否需要自动停止
            if (alarm_active) begin
                // 闹钟已经在响，但时间已经过去
                if (alarm_duration < 5'b11110) begin  // 继续响30秒
                    alarm_duration <= alarm_duration + 1'b1;
                end else begin
                    // 30秒后自动停止
                    alarm_active <= 1'b0;
                    melody_state <= 1'b0;
                    beep_counter <= 2'b00;
                    alarm_duration <= 5'b00000;
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
        cnt <= 4'b0000;
        sec_cnt <= 4'b0000;
        thi_cnt <= 4'b0000;
        four_cnt <= 4'b0000;
        five_cnt <= 4'b0000;
        six_cnt <= 4'b0000;
    end else if (set_clk_rise && set_clr && !set_alarm) begin
        // 设置当前时间
        if (set_sec) begin
            if (cnt == 4'b1001) begin
                cnt <= 4'b0000;
                if (sec_cnt == 4'b0101) sec_cnt <= 4'b0000;
                else sec_cnt <= sec_cnt + 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end else if (set_min) begin
            if (thi_cnt == 4'b1001) begin
                thi_cnt <= 4'b0000;
                if (four_cnt == 4'b0101) four_cnt <= 4'b0000;
                else four_cnt <= four_cnt + 1'b1;
            end else begin
                thi_cnt <= thi_cnt + 1'b1;
            end
        end else if (set_hour) begin
            if (five_cnt == 4'b1001) begin
                five_cnt <= 4'b0000;
                if (six_cnt == 4'b0010) six_cnt <= 4'b0000;
                else six_cnt <= six_cnt + 1'b1;
            end else if (six_cnt == 4'b0010 && five_cnt == 4'b0011) begin
                five_cnt <= 4'b0000;
                six_cnt <= 4'b0000;
            end else begin
                five_cnt <= five_cnt + 1'b1;
            end
        end
    end else if (!set_clr && !set_alarm && clk_1hz) begin
        // 正常计时
        if (cnt == 4'b1001) begin
            cnt <= 4'b0000;
            if (sec_cnt == 4'b0101) begin
                sec_cnt <= 4'b0000;
                if (thi_cnt == 4'b1001) begin
                    thi_cnt <= 4'b0000;
                    if (four_cnt == 4'b0101) begin
                        four_cnt <= 4'b0000;
                        if (six_cnt == 4'b0010 && five_cnt == 4'b0011) begin
                            five_cnt <= 4'b0000;
                            six_cnt <= 4'b0000;
                        end else if (five_cnt == 4'b1001) begin
                            five_cnt <= 4'b0000;
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
        alarm_thi_cnt <= 4'b0000;
        alarm_four_cnt <= 4'b0000;
        alarm_five_cnt <= 4'b0000;
        alarm_six_cnt <= 4'b0000;
    end else if (set_clk_rise && set_alarm) begin
        if (set_min) begin
            if (alarm_thi_cnt == 4'b1001) begin
                alarm_thi_cnt <= 4'b0000;
                if (alarm_four_cnt == 4'b0101) alarm_four_cnt <= 4'b0000;
                else alarm_four_cnt <= alarm_four_cnt + 1'b1;
            end else begin
                alarm_thi_cnt <= alarm_thi_cnt + 1'b1;
            end
        end else if (set_hour) begin
            if (alarm_five_cnt == 4'b1001) begin
                alarm_five_cnt <= 4'b0000;
                if (alarm_six_cnt == 4'b0010) alarm_six_cnt <= 4'b0000;
                else alarm_six_cnt <= alarm_six_cnt + 1'b1;
            end else if (alarm_six_cnt == 4'b0010 && alarm_five_cnt == 4'b0011) begin
                alarm_five_cnt <= 4'b0000;
                alarm_six_cnt <= 4'b0000;
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
        4'b0000: seg_cnt = 7'b0111111;
        4'b0001: seg_cnt = 7'b0000110;
        4'b0010: seg_cnt = 7'b1011011;
        4'b0011: seg_cnt = 7'b1001111;
        4'b0100: seg_cnt = 7'b1100110;
        4'b0101: seg_cnt = 7'b1101101;
        4'b0110: seg_cnt = 7'b1111101;
        4'b0111: seg_cnt = 7'b0000111;
        4'b1000: seg_cnt = 7'b1111111;
        4'b1001: seg_cnt = 7'b1101111;
        default: seg_cnt = 7'b0000000;
    endcase
end

reg [6:0] seg_alarm_thi;
always @(*) begin
    case (alarm_thi_cnt)
        4'b0000: seg_alarm_thi = 7'b0111111;
        4'b0001: seg_alarm_thi = 7'b0000110;
        4'b0010: seg_alarm_thi = 7'b1011011;
        4'b0011: seg_alarm_thi = 7'b1001111;
        4'b0100: seg_alarm_thi = 7'b1100110;
        4'b0101: seg_alarm_thi = 7'b1101101;
        4'b0110: seg_alarm_thi = 7'b1111101;
        4'b0111: seg_alarm_thi = 7'b0000111;
        4'b1000: seg_alarm_thi = 7'b1111111;
        4'b1001: seg_alarm_thi = 7'b1101111;
        default: seg_alarm_thi = 7'b0000000;
    endcase
end

// ================== 输出 ==================
assign seg = set_alarm ? seg_alarm_thi : seg_cnt;
assign sec  = set_alarm ? 4'b0000 : sec_cnt;
assign thi  = set_alarm ? alarm_thi_cnt : thi_cnt;
assign four = set_alarm ? alarm_four_cnt : four_cnt;
assign five = set_alarm ? alarm_five_cnt : five_cnt;
assign six  = set_alarm ? alarm_six_cnt : six_cnt;
assign alarm_flag = alarm_active | hourly_beep_active;  // 闹钟标志包括整点报时

endmodule