module count(
    input clk,
    input set_clk,
    input set_hour,
    input set_min,
    input set_sec,
    input rst,
    input [6:0] seg,
    input [3:0] sec,
    input [3:0] thi,
    input [3:0] fou,
    input [3:0] five,
    input [3:0] six
);

reg [3:0] cnt;
reg [3:0] sec_cnt;
reg [3:0] thi_cnt;
reg [3:0] fou_cnt;
reg [3:0] five_cnt;
reg [3:0] six_cnt;

always @(posedge clk or posedge rst) begin
    if (!rst) begin
        cnt <= 0;
        sec_cnt <= 0;
        thi_cnt <= 0;
        fou_cnt <= 0;
        five_cnt <= 0;
        six_cnt <= 0;
    end else if (cnt==4'd9) begin
        cnt <= 4'd0;
        if(sec_cnt==5) begin
            sec_cnt <= 0;
            if(thi_cnt==4'd9) begin
                thi_cnt <= 0;
                if(fou_cnt==5) begin
                    fou_cnt <= 0;
                    if(six_cnt==2&&five_cnt==3) begin
                        five_cnt <= 0;
                        six_cnt <= 0;
                    end
                    else if(five_cnt==4'd9) begin
                        five_cnt <= 0;
                        six_cnt <= six_cnt + 1;
                    end
                    else begin
                        five_cnt <= five_cnt + 1;
                    end
                end
                else begin
                    fou_cnt <= fou_cnt + 1;
                end
            end
            else begin
                thi_cnt <= thi_cnt + 1;
            end
        end
        else begin
            sec_cnt <= sec_cnt + 1;
        end
    end
end

reg [6:0] seg_out;
always @(cnt) begin
        case (cnt)
            4'd0: seg_out <= 7'b0111111;
            4'd1: seg_out <= 7'b0000110;
            4'd2: seg_out <= 7'b1011011;
            4'd3: seg_out <= 7'b1001111;
            4'd4: seg_out <= 7'b1100110;
            4'd5: seg_out <= 7'b1101101;
            4'd6: seg_out <= 7'b1111101;
            4'd7: seg_out <= 7'b0000111;
            4'd8: seg_out <= 7'b1111111;
            4'd9: seg_out <= 7'b1101111;
            default: seg_out = 7'b0000000;
        endcase
    end

assign seg=seg_out;
assign sec=sec_cnt;
assign thi=thi_cnt;
assign fou=fou_cnt;
assign five=five_cnt;
assign six=six_cnt;


endmodule
