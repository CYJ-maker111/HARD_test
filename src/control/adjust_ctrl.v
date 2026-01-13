/**
 * 校时控制模块
 * 功能：解析用户输入，控制小时/分钟调整
 * 控制逻辑：
 *   K0=1: 进入校时模式（暂停自动计时）
 *     K1=1: QD上升沿 -> 小时+1
 *     K2=1: QD上升沿 -> 分钟+1
 *   K0=0: 退出校时，恢复正常计时
 */
module adjust_ctrl (
    input  wire clk,        // 系统时钟
    input  wire rst_n,      // 复位信号（低有效）
    input  wire K0,         // 校时使能开关
    input  wire K1,         // 小时调整选择
    input  wire K2,         // 分钟调整选择
    input  wire QD,         // 校时确认按钮（需防抖）
    output reg  hour_en,    // 小时校时使能（脉冲）
    output reg  min_en      // 分钟校时使能（脉冲）
);

    // 按钮边沿检测
    wire qd_edge;
    edge_detect u_edge_detect (
        .clk(clk),
        .rst_n(rst_n),
        .signal_in(QD),
        .edge_out(qd_edge)
    );
    
    // 校时控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hour_en <= 1'b0;
            min_en <= 1'b0;
        end else begin
            hour_en <= 1'b0;
            min_en <= 1'b0;
            
            if (K0) begin  // 校时模式
                if (qd_edge) begin  // QD按钮上升沿
                    if (K1) begin  // 小时调整
                        hour_en <= 1'b1;
                    end else if (K2) begin  // 分钟调整
                        min_en <= 1'b1;
                    end
                end
            end
        end
    end

endmodule

