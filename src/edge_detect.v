/**
 * 边沿检测模块
 * 功能：检测输入信号的上升沿，用于按钮防抖
 * 实现：两级寄存器同步 + 边沿检测
 */
module edge_detect (
    input  wire clk,      // 系统时钟
    input  wire rst_n,    // 复位信号（低有效）
    input  wire signal_in, // 输入信号（异步）
    output reg  edge_out  // 上升沿输出（单周期脉冲）
);

    // 两级寄存器同步，防止亚稳态
    reg sync1, sync2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= signal_in;
            sync2 <= sync1;
        end
    end
    
    // 上升沿检测：当前为1，前一个周期为0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_out <= 1'b0;
        end else begin
            // 当前拍为1，上一拍为0 -> 上升沿
            edge_out <= sync1 & ~sync2;  // 检测上升沿
        end
    end

endmodule

