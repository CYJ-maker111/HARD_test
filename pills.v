module pills (
    input        clk,      // 时钟输入（1kHz）
    input        k0,       // pin 54 — 总开关（1=开机）
    input        k1,       // 全部清零
    input        k2,       // 开始运行/暂停
    input        k4,       // pin 60 — 进入设置模式
    input        k5,       // pin 61 — 选择设置每个瓶子数量上限
    input        k6,       // pin 63 — 选择设置总瓶子数量
    input        k7,       // 错误状态触发
    input        switch,   // 切换上限

    output [6:0] LG1,      // 状态显示
    output reg [3:0] LG2,      // 当前瓶药片数个位
    output reg [3:0] LG3,      // 当前瓶药片数十位
    output reg [3:0] LG4,      // 已装满瓶数个位
    output reg [3:0] LG5,      // 已装满瓶数十位
    output reg [3:0] LG6,      // 已装满瓶数百位
    output       buzzer    // 蜂鸣器
);

// ========== 参数定义 ==========
parameter S_IDLE    = 3'b000;  // 空闲状态
parameter S_PAUSE   = 3'b001;  // 暂停状态（默认状态）
parameter S_SETUP   = 3'b010;  // 设置状态
parameter S_RUN     = 3'b011;  // 运行状态
parameter S_ERROR   = 3'b100;  // 错误状态

// 七段数码管编码（共阴极）
parameter SEG_S = 7'b1101101;  // S
parameter SEG_C = 7'b0111001;  // C
parameter SEG_P = 7'b1110011;  // P
parameter SEG_E = 7'b1111001;  // E
parameter SEG_BLANK = 7'b1111111;

// 蜂鸣器模式
parameter BEEP_COMPLETE = 2'b00;   // 完成提示音
parameter BEEP_ALARM    = 2'b01;   // 警报声
parameter BEEP_ALARM_FAST = 2'b10; // 快速警报声（错误状态）

// ========== 寄存器定义 ==========
reg [2:0] state;           // 扩展状态位到3位
reg beep_enable;           // 蜂鸣器使能控制
reg finished;              // 完成标志

// 边沿检测
reg switch_last;          // switch边沿检测

// 显示值
reg [6:0] seg_state;

// 蜂鸣器频率生成（500Hz）
reg [1:0] tone_counter;   // 2位计数器即可生成500Hz
reg beep_tone;
reg [1:0] beep_mode;      // 蜂鸣器模式
reg alarm_enable;         // 警报声使能控制（开启/关闭警报节奏）

reg [9:0] lighting_counter;// 频闪计时器
reg light_state;
reg [7:0] alarm_counter;  // 警报声计时器

// 设置参数 - 使用BCD码直接存储
reg [3:0] total_hundreds, total_tens, total_ones;    // 总瓶数BCD码
reg [3:0] pills_tens, pills_ones;                    // 每瓶药片数BCD码

// 运行状态寄存器 - 使用BCD码直接存储
reg [3:0] current_pills_tens, current_pills_ones;    // 当前瓶药片数BCD码
reg [3:0] done_hundreds, done_tens, done_ones;       // 已装满瓶数BCD码
reg [9:0] timer;               // 1秒计时器
reg [11:0] beep_timer;         // 蜂鸣器计时器（12位，最大4秒）

// 设置选择标志
reg setting_pills;  // 1:正在设置每瓶药片数
reg setting_total;  // 1:正在设置总瓶数

// 错误状态标志
reg error_flag;     // 错误状态标志

// ========== 组合逻辑 ==========
// 边沿检测
wire switch_rise;
assign switch_rise = switch && !switch_last;

// ========== 分频器 ============

always @(posedge clk) begin

    if(lighting_counter == 10'd999) begin
        lighting_counter <= 1'b0;
        if(light_state == 1'b1)
            light_state <= 1'b0;
        else
            light_state <= 1'b1;
    end
    else
        lighting_counter <= lighting_counter + 1'b1;    

end

// ========== 主状态机 ==========
always @(posedge clk) begin
    // 保存上一次状态用于边沿检测
    switch_last <= switch;
    
    // 警报声计时器更新
    if (beep_mode == BEEP_ALARM || beep_mode == BEEP_ALARM_FAST) begin
        if (alarm_counter == 8'd0) begin
            alarm_enable <= ~alarm_enable;  // 切换警报声的开启/关闭状态
            
            // 设置不同警报声的节奏
            if (beep_mode == BEEP_ALARM) begin
                // 标准警报声：每秒响1次（开500ms，关500ms）
                if (alarm_enable == 1'b1) begin
                    alarm_counter <= 8'd250; // 500ms开启
                end else begin
                    alarm_counter <= 8'd250; // 500ms关闭
                end
            end else begin
                // 快速警报声（错误状态）：每秒响2次（开250ms，关250ms）
                if (alarm_enable == 1'b1) begin
                    alarm_counter <= 8'd125; // 250ms开启
                end else begin
                    alarm_counter <= 8'd125; // 250ms关闭
                end
            end
        end else begin
            alarm_counter <= alarm_counter - 8'd1;
        end
    end else begin
        alarm_enable <= 1'b0;
        alarm_counter <= 8'd0;
    end
    
    // 总开关控制
    if (!k0) begin
        state <= S_IDLE;
        // 重置所有寄存器
        current_pills_tens <= 4'b0000;
        current_pills_ones <= 4'b0000;
        done_hundreds <= 4'b0000;
        done_tens <= 4'b0000;
        done_ones <= 4'b0000;
        timer <= 10'b0000000000;
        beep_timer <= 12'b000000000000;
        beep_enable <= 1'b0;
        finished <= 1'b0;
        setting_pills <= 1'b0;
        setting_total <= 1'b0;
        error_flag <= 1'b0;
        beep_mode <= BEEP_COMPLETE;
        alarm_enable <= 1'b0;
        alarm_counter <= 8'd0;
        
        // 默认设置：总瓶数2，每瓶10片
        total_hundreds <= 4'b0000;
        total_tens <= 4'b0000;
        total_ones <= 4'b0010;  // 2
        
        pills_tens <= 4'b0001;  // 十位1
        pills_ones <= 4'b0000;  // 个位0
    end
    // 清零按钮
    else if (k1) begin
        current_pills_tens <= 4'b0000;
        current_pills_ones <= 4'b0000;
        done_hundreds <= 4'b0000;
        done_tens <= 4'b0000;
        done_ones <= 4'b0000;
        timer <= 10'b0000000000;
        beep_timer <= 12'b000000000000;
        if (!error_flag) begin  // 如果不在错误状态，才清除蜂鸣器
            beep_enable <= 1'b0;
            beep_mode <= BEEP_COMPLETE;
            alarm_enable <= 1'b0;
            alarm_counter <= 8'd0;
        end
        finished <= 1'b0;
        // 注意：不清除错误标志，需要手动解除错误状态
    end
    else begin
        // 蜂鸣器计时控制（仅对完成提示音有效）
        if (beep_enable && beep_mode == BEEP_COMPLETE) begin
            // 检查是否全部装完
            // BCD比较逻辑：先比较百位，再比较十位，最后比较个位
            if ((done_hundreds > total_hundreds) ||
                (done_hundreds == total_hundreds && done_tens > total_tens) ||
                (done_hundreds == total_hundreds && done_tens == total_tens && done_ones >= total_ones)) begin
                // 全部装完：长响4秒
                if (beep_timer < 12'b111110100000) begin  // 4000
                    beep_timer <= beep_timer + 12'b000000000001;
                end else begin
                    beep_enable <= 1'b0;
                    beep_timer <= 12'b000000000000;
                    finished <= 1'b1;
                end
            end else begin
                // 装完一瓶：短响30ms
                if (beep_timer < 12'b000000011110) begin  // 30
                    beep_timer <= beep_timer + 12'b000000000001;
                end else begin
                    beep_enable <= 1'b0;
                    beep_timer <= 12'b000000000000;
                end
            end
        end
        
        case (state)
            S_IDLE: begin
                if (k0) begin
                    // 开机默认进入暂停状态
                    state <= S_PAUSE;
                    // 重置运行状态
                    current_pills_tens <= 4'b0000;
                    current_pills_ones <= 4'b0000;
                    done_hundreds <= 4'b0000;
                    done_tens <= 4'b0000;
                    done_ones <= 4'b0000;
                    finished <= 1'b0;
                    setting_pills <= 1'b0;
                    setting_total <= 1'b0;
                    error_flag <= 1'b0;
                    beep_mode <= BEEP_COMPLETE;
                    alarm_enable <= 1'b0;
                    alarm_counter <= 8'd0;
                end
            end
            
            S_PAUSE: begin
                // 检查错误状态触发
                if (k7) begin
                    state <= S_ERROR;
                    error_flag <= 1'b1;
                    beep_mode <= BEEP_ALARM_FAST;  // 进入错误状态，启用快速警报声
                    beep_enable <= 1'b1;          // 启用蜂鸣器
                    alarm_enable <= 1'b1;         // 开始警报
                end
                // 进入设置模式 - 当k4为1时
                else if (k4) begin
                    state <= S_SETUP;
                    setting_pills <= 1'b0;
                    setting_total <= 1'b0;
                end
                // 开始运行 - k2为1时进入运行状态
                else if (k2) begin
                    state <= S_RUN;
                end
            end
            
            S_SETUP: begin
                // 检查错误状态触发
                if (k7) begin
                    state <= S_ERROR;
                    error_flag <= 1'b1;
                    beep_mode <= BEEP_ALARM_FAST;  // 进入错误状态，启用快速警报声
                    beep_enable <= 1'b1;          // 启用蜂鸣器
                    alarm_enable <= 1'b1;         // 开始警报
                end
                // 退出设置模式 - 当k4为0时回到暂停状态
                else if (!k4) begin
                    state <= S_PAUSE;
                end
                else begin
                    // 设置选择
                    if (k5) begin
                        setting_pills <= 1'b1;
                        setting_total <= 1'b0;
                    end
                    else if (k6) begin
                        setting_total <= 1'b1;
                        setting_pills <= 1'b0;
                    end
                    
                    // 切换设置值 - switch上升沿触发
                    if (switch_rise) begin
                        if (setting_pills) begin
                            // 设置每瓶药片数：10→20→50→10
                            if (pills_tens == 4'b0001 && pills_ones == 4'b0000) begin // 10
                                pills_tens <= 4'b0010; // 20
                                pills_ones <= 4'b0000;
                            end
                            else if (pills_tens == 4'b0010 && pills_ones == 4'b0000) begin // 20
                                pills_tens <= 4'b0101; // 50
                                pills_ones <= 4'b0000;
                            end
                            else begin // 50或其它
                                pills_tens <= 4'b0001; // 10
                                pills_ones <= 4'b0000;
                            end
                        end
                        else if (setting_total) begin
                            // 设置总瓶数：2→10→50→100→2
                            if (total_hundreds == 4'b0000 && total_tens == 4'b0000 && total_ones == 4'b0010) begin // 2
                                total_hundreds <= 4'b0000;
                                total_tens <= 4'b0001; // 10
                                total_ones <= 4'b0000;
                            end
                            else if (total_hundreds == 4'b0000 && total_tens == 4'b0001 && total_ones == 4'b0000) begin // 10
                                total_hundreds <= 4'b0000;
                                total_tens <= 4'b0101; // 50
                                total_ones <= 4'b0000;
                            end
                            else if (total_hundreds == 4'b0000 && total_tens == 4'b0101 && total_ones == 4'b0000) begin // 50
                                total_hundreds <= 4'b0001; // 100
                                total_tens <= 4'b0000;
                                total_ones <= 4'b0000;
                            end
                            else begin // 100或其它
                                total_hundreds <= 4'b0000;
                                total_tens <= 4'b0000;
                                total_ones <= 4'b0010; // 2
                            end
                        end
                    end
                end
            end
            
            S_RUN: begin
                // 检查错误状态触发
                if (k7) begin
                    state <= S_ERROR;
                    error_flag <= 1'b1;
                    beep_mode <= BEEP_ALARM_FAST;  // 进入错误状态，启用快速警报声
                    beep_enable <= 1'b1;          // 启用蜂鸣器
                    alarm_enable <= 1'b1;         // 开始警报
                end
                // 暂停（回到暂停状态）- k2为0时暂停
                else if (!k2) begin
                    state <= S_PAUSE;
                end
                // 检查是否全部装完且未完成蜂鸣
                else if (((done_hundreds > total_hundreds) ||
                         (done_hundreds == total_hundreds && done_tens > total_tens) ||
                         (done_hundreds == total_hundreds && done_tens == total_tens && done_ones >= total_ones)) && !finished) begin
                    if (!beep_enable) begin
                        beep_enable <= 1'b1;
                        beep_mode <= BEEP_COMPLETE;  // 使用完成提示音模式
                        beep_timer <= 12'b000000000000;
                    end
                end
                // 正常装瓶 - 检查是否未完成所有瓶子
                else if (!((done_hundreds > total_hundreds) ||
                          (done_hundreds == total_hundreds && done_tens > total_tens) ||
                          (done_hundreds == total_hundreds && done_tens == total_tens && done_ones >= total_ones))) begin
                    // 1秒装一片
                    if (timer < 10'b1111100111) begin  // 999
                        timer <= timer + 10'b0000000001;
                    end
                    else begin
                        timer <= 10'b0000000000;  // 1秒到
                        
                        // 检查当前瓶是否已满
                        // 比较当前药片数是否小于设置值
                        if ((current_pills_tens < pills_tens) || 
                            (current_pills_tens == pills_tens && current_pills_ones < pills_ones)) begin
                            // 当前瓶未满，药片数加1（BCD加法）
                            if (current_pills_ones == 4'b1001) begin  // 个位为9
                                current_pills_ones <= 4'b0000;
                                current_pills_tens <= current_pills_tens + 4'b0001;
                            end else begin
                                current_pills_ones <= current_pills_ones + 4'b0001;
                            end
                        end
                        else begin
                            // 当前瓶已满
                            current_pills_tens <= 4'b0000;
                            current_pills_ones <= 4'b0000;
                            
                            // 已装瓶数加1（BCD加法）
                            if (done_ones == 4'b1001) begin  // 个位为9
                                done_ones <= 4'b0000;
                                if (done_tens == 4'b1001) begin  // 十位为9
                                    done_tens <= 4'b0000;
                                    done_hundreds <= done_hundreds + 4'b0001;
                                end else begin
                                    done_tens <= done_tens + 4'b0001;
                                end
                            end else begin
                                done_ones <= done_ones + 4'b0001;
                            end
                            
                            // 短响一声（30ms）
                            beep_enable <= 1'b1;
                            beep_mode <= BEEP_COMPLETE;  // 使用完成提示音模式
                            beep_timer <= 12'b000000000000;
                        end
                    end
                end
            end
            
            S_ERROR: begin
                // 错误状态：所有操作暂停
                // 只有k7为0时才能退出错误状态
                if (!k7) begin
                    error_flag <= 1'b0;   // 解除错误标志
                    state <= S_PAUSE;     // 回到暂停状态
                    beep_mode <= BEEP_COMPLETE; // 恢复默认蜂鸣模式
                    beep_enable <= 1'b0;  // 关闭蜂鸣器
                    alarm_enable <= 1'b0; // 关闭警报声
                    alarm_counter <= 8'd0; // 重置计数器
                end
                // 错误状态下持续警报声
            end
        endcase
    end
end

// ========== 音调生成逻辑 ==========
always @(posedge clk) begin
    if (tone_counter == 2'b01) begin
        tone_counter <= 2'b00;
        beep_tone <= ~beep_tone;  // 每2个周期翻转一次 = 500Hz
    end else begin
        tone_counter <= tone_counter + 2'b01;
    end
end

// ========== 显示逻辑 ==========
always @(posedge clk) begin
    // 状态显示
    case (state)
        S_SETUP: seg_state <= SEG_S;
        S_RUN: seg_state <= SEG_C;
        S_PAUSE: seg_state <= SEG_P;
        S_ERROR: seg_state <= SEG_E;
        default: seg_state <= SEG_BLANK;
    endcase
end

// ========== 输出 ==========
assign LG1 = seg_state;

// ========== 优化的显示逻辑 ==========
// 判断是否显示设置值：设置状态或已完成（包括运行、暂停、错误状态下的已完成）

// 数码管输出
always @( posedge clk ) begin
     
    if( state == S_SETUP ) begin
        LG2 <= light_state ? pills_ones : 4'b0000;  // 个位
        LG3 <= light_state ? pills_tens : 4'b0000;  // 十位

        LG4 <= light_state ? total_ones : 4'b0000;  // 个位
        LG5 <= light_state ? total_tens : 4'b0000;  // 十位
        LG6 <= light_state ? total_hundreds : 4'b0000;  // 百位
    end else begin
        LG2 <= (finished == 1'b1) ? pills_ones : current_pills_ones;  // 个位
        LG3 <= (finished == 1'b1) ? pills_tens : current_pills_tens;  // 十位

        LG4 <= (finished == 1'b1) ? total_ones : done_ones;          // 个位
        LG5 <= (finished == 1'b1) ? total_tens : done_tens;          // 十位
        LG6 <= (finished == 1'b1) ? total_hundreds : done_hundreds;  // 百位
    end

end

// ========== 蜂鸣器输出逻辑 ==========
// 警报声模式下：使用500Hz蜂鸣声，但根据警报节奏开启/关闭
// 完成提示音模式下：持续500Hz蜂鸣声
assign buzzer = (
    (beep_mode == BEEP_COMPLETE) ? (beep_enable && beep_tone) :  // 完成提示音：500Hz连续音
    (beep_mode == BEEP_ALARM || beep_mode == BEEP_ALARM_FAST) ? (beep_enable && alarm_enable && beep_tone) : // 警报声：500Hz断续音
    1'b0
);

endmodule