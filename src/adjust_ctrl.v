/**
 * 校时控制模块（改进版）
 * 功能：
 *   - K1=1: 小时校时使能
 *   - K2=1: 分钟校时使能
 *   - K1 & K2 = 1: 优先小时（K1）
 *   - CLR 按下（下降沿）→ 触发 +1
 * 注意：仅在校时模式（由顶层 K0 控制）下生效，
 *       但本模块不处理 K0，由顶层决定是否传递 hour_en/min_en
 */
module adjust_ctrl (
    input  wire clk,        // 高频系统时钟（如 CP2 = 100Hz）
    input  wire rst_n,      // 复位（低有效）
    input  wire K1,         // 小时校时使能（拨码开关）
    input  wire K2,         // 分钟校时使能（拨码开关）
    input  wire QD,        // 校时按钮（低有效，按下=0）
    output reg  hour_en,    // 小时+1 脉冲（单周期高）
    output reg  min_en      // 分钟+1 脉冲（单周期高）
);

    同步 CLR 信号（防亚稳态）
    reg qd_sync0, qd_sync1;
    always @(posedge QD or negedge rst_n) begin
        if (!rst_n) begin
            qd_sync0 <= 1'b1;
            qd_sync1 <= 1'b1;
        end else begin
            qd_sync0 <= QD;
            qd_sync1 <= clr_sync0;
        end
    end

    // 检测 CLR 按下（下降沿：1 → 0）
    wire qd_pressed = ~qd_sync0 & qd_sync1;

    // 主控制逻辑
    always @(posedge clk or negedge QD) begin
        hour_en <= 1'b0;
        min_en  <= 1'b0;

        // 仅在 CLR 按下瞬间触发
        if (!QD) begin
            if (K1) begin          // K1 优先
                hour_en <= 1'b1;
            end else if (K2) begin // 仅当 K1=0 且 K2=1 时
                min_en <= 1'b1;
            end
            // 若 K1=K2=0，则无操作
        end
    end

endmodule