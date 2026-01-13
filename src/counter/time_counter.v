/**
 * 时间计数模块
 * 功能：实现HH:MM:SS的BCD计数与进位逻辑
 * 计数范围：时(0-23)、分(0-59)、秒(0-59)
 * 输出格式：BCD编码（个位[3:0] + 十位[6:4]）
 */
module time_counter (
    input  wire clk_1hz,      // 1Hz时钟（来自CP3）
    input  wire rst_n,        // 复位信号（低有效）
    input  wire hour_en,      // 小时校时使能（脉冲）
    input  wire min_en,       // 分钟校时使能（脉冲）
    output reg  [4:0] hour,   // 小时输出（BCD：十位[4:1]，个位[0]，实际为简化BCD）
    output reg  [6:0] minute, // 分钟输出（BCD：十位[6:4]，个位[3:0]）
    output reg  [6:0] second  // 秒输出（BCD：十位[6:4]，个位[3:0]）
);

    // 秒计数器（0-59，BCD格式）
    reg sec_carry;
    
    always @(posedge clk_1hz or negedge rst_n) begin
        if (!rst_n) begin
            second <= 7'd0;//秒计数器初始化
            sec_carry <= 1'b0;//秒进位标志初始化
        end else if (!hour_en && !min_en) begin  // 正常计时模式
            sec_carry <= 1'b0;//秒进位标志清零  
            if (second[3:0] >= 4'd9) begin  // 个位9，需要进位
                second[3:0] <= 4'd0;//秒个位归零
                if (second[6:4] >= 3'd5) begin  // 十位5，归零
                    second[6:4] <= 3'd0;//秒十位归零
                    sec_carry <= 1'b1;//秒进位标志置1
                end else begin
                    second[6:4] <= second[6:4] + 1'b1;//秒十位加1
                end
            end else begin
                second[3:0] <= second[3:0] + 1'b1;//秒个位加1
            end
        end
    end
    
    // 分钟计数器（0-59，BCD格式）
    reg min_carry;
    
    always @(posedge clk_1hz or negedge rst_n) begin
        if (!rst_n) begin
            minute <= 7'd0;//分钟计数器初始化
            min_carry <= 1'b0;//分钟进位标志初始化
        end else if (min_en) begin  // 分钟校时模式
            min_carry <= 1'b0;//分钟进位标志清零  
            if (minute[3:0] >= 4'd9) begin//分钟个位大于9
                minute[3:0] <= 4'd0;//分钟个位归零
                if (minute[6:4] >= 3'd5) begin
                    minute[6:4] <= 3'd0;//分钟十位归零
                end else begin
                    minute[6:4] <= minute[6:4] + 1'b1;//分钟十位加1
                end
            end else begin
                minute[3:0] <= minute[3:0] + 1'b1;//分钟个位加1
            end
        end else if (sec_carry) begin  // 秒进位
            min_carry <= 1'b0;//分钟进位标志清零        
            if (minute[3:0] >= 4'd9) begin
                minute[3:0] <= 4'd0;//分钟个位归零
                if (minute[6:4] >= 3'd5) begin
                    minute[6:4] <= 3'd0;//分钟十位归零
                    min_carry <= 1'b1;//分钟进位标志置1
                end else begin
                    minute[6:4] <= minute[6:4] + 1'b1;//分钟十位加1
                end
            end else begin
                minute[3:0] <= minute[3:0] + 1'b1;//分钟个位加1
            end
        end
    end
    
    // 小时计数器（0-23，BCD格式）
    // hour[4:1]: 十位（0-2），hour[0]: 个位（0-9）
    // 使用内部二进制计数器，输出时转换为简化BCD格式
    reg [4:0] hour_bin;  // 内部二进制计数器（0-23）
    
    always @(posedge clk_1hz or negedge rst_n) begin
        if (!rst_n) begin
            hour_bin <= 5'd0;//小时计数器初始化
            hour <= 5'd0;//小时输出初始化
        end else begin
            if (hour_en || min_carry) begin//小时校时模式或分钟进位
                if (hour_bin >= 5'd23) begin//小时计数器大于23
                    hour_bin <= 5'd0;//小时计数器归零
                end else begin//小时计数器小于23    
                    hour_bin <= hour_bin + 1'b1;//小时计数器加1
                end
            end
            
            // 转换为BCD格式：hour[4:1]为十位，hour[0]为个位最低位
            // 简化处理：直接使用二进制高位作为十位，低位作为个位
            hour[0] <= hour_bin[0];//小时个位输出
            hour[4:1] <= hour_bin[4:1];//小时十位输出  
        end
    end

endmodule

