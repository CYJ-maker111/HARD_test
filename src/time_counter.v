module time_counter (
    input  wire clk,          // CP2, 100Hz 主时钟
    input  wire rst_n,
    input  wire K0,           // 校时模式使能（K0=1：校时；K0=0：走时）
    input  wire K1,
    input  wire K2,
    input  wire QD,
    output reg [4:0] hour,
    output reg [5:0] minute,
    output reg [5:0] second
);

    // 100Hz -> 1Hz 分频器（100 个周期 = 1 秒）
    reg [6:0] cnt_1s;
    reg tick_1s; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1s <= 7'd0;
        end else begin
            tick_1s <= 1'b0;
            // ===== 1秒分频 =====
            if (cnt_1s == 7'd99) begin
                cnt_1s <= 7'd0;
                tick_1s <= 1'b1;
            end
            else
                cnt_1s <= cnt_1s + 1'b1;
        end
    end

    // === 按钮同步与边沿检测（CLR 下降沿 = 按下）===
    reg QD_d0, QD_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            QD_d0 <= 1'b1;
            QD_d1 <= 1'b1;
        end else begin
            QD_d0 <= QD;
            QD_d1 <= QD_d0;
        end
    end
    wire QD_pressed = ~QD_d0 & QD_d1;  // 按下瞬间（下降沿）

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            second <= 6'd0;
            minute <= 6'd0;
            hour   <= 5'd0;
        end else begin
            
            if (K0) begin // 校时模式
                if (QD_pressed) begin
                    if (K1)
                        hour <= (hour == 5'd23) ? 5'd0 : hour + 1'b1;
                    if (K2)
                        minute <= (minute == 6'd59) ? 6'd0 : minute + 1'b1;
                end
                // second 不在校时中调整，可选
            end
            // ===== 自动计时逻辑（仅在非校时模式）=====
            else if (tick_1s) begin // 每秒走一次
                if (second == 6'd59) begin
                    second <= 6'd0;
                    if (minute == 6'd59) begin
                        minute <= 6'd0;
                        hour <= (hour == 5'd23) ? 5'd0 : hour + 1'b1;
                    end else begin
                        minute <= minute + 1'b1;
                    end
                end else begin
                    second <= second + 1'b1;
                end
            end
        end
    end
endmodule