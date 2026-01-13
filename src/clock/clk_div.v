/**
 * 时钟分频模块（备用）
 * 功能：将高频时钟分频为1Hz时钟
 * 说明：优先使用外部CP3（1Hz）信号，此模块作为备用方案
 */
module clk_div (
    input  wire clk_in,   // 输入时钟（如10MHz）
    input  wire rst_n,    // 复位信号（低有效）
    output reg  clk_1hz   // 输出1Hz时钟
);

    // 假设输入时钟为10MHz，需要分频到1Hz
    // 分频比 = 10,000,000 / 1 = 10,000,000
    // 计数器需要计数到 5,000,000（半周期翻转）
    parameter DIV_CNT = 26'd5000000;  // 10MHz -> 1Hz 的分频计数
    
    reg [25:0] cnt;  // 分频计数器
    
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 26'd0;
            clk_1hz <= 1'b0;
        end else begin
            if (cnt >= DIV_CNT - 1) begin
                cnt <= 26'd0;
                clk_1hz <= ~clk_1hz;  // 翻转输出时钟
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule

