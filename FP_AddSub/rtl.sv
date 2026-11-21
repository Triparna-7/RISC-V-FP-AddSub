
module fp_addsub_core (
    input logic [31:0] a, b,
    input logic sub,
    output logic [31:0] result
);

    function automatic [26:0] shift_sticky(input logic [26:0] x, input integer n);
        logic [26:0] y;
        logic sticky;
        integer k;
        begin
            y = '0;
            sticky = 1'b0;
            if (n == 0) y = x;
            else if (n >= 27) y[0] = |x;
            else begin
                y = x >> n;
                for (k = 0; k < 27; k = k + 1)
                    if (k < n) sticky = sticky | x[k];
                y[0] = y[0] | sticky;
            end
            shift_sticky = y;
        end
    endfunction

    function automatic [31:0] calculate(input logic [31:0] x, y, input logic subtract);
        logic sx, sy, sign_big, sign_small, sign_res;
        logic [7:0] ex, ey, exp_field;
        logic [22:0] fx, fy;
        logic [26:0] mx, my, big, smaller, norm;
        logic [27:0] total;
        logic [24:0] rounded;
        logic [23:0] fraction24;
        logic guardbit, roundbit, stickybit;
        integer expx, expy, expbig, expsmall, expout, delta, j;
        logic [31:0] answer;
        begin
            sx = x[31];
            sy = y[31] ^ subtract;
            ex = x[30:23];
            ey = y[30:23];
            fx = x[22:0];
            fy = y[22:0];
            answer = 32'b0;

            if ((ex == 8'hff && fx != 0) || (ey == 8'hff && fy != 0) ||
                (ex == 8'hff && ey == 8'hff && sx != sy)) begin
                answer = 32'h7fc00000;
            end else if (ex == 8'hff) begin
                answer = {sx, 8'hff, 23'b0};
            end else if (ey == 8'hff) begin
                answer = {sy, 8'hff, 23'b0};
            end else begin
                expx = ex == 0 ? 1 : ex;
                expy = ey == 0 ? 1 : ey;
                mx = {ex != 0, fx, 3'b000};
                my = {ey != 0, fy, 3'b000};

                if (expx > expy || (expx == expy && mx >= my)) begin
                    big = mx;
                    smaller = my;
                    expbig = expx;
                    expsmall = expy;
                    sign_big = sx;
                    sign_small = sy;
                end else begin
                    big = my;
                    smaller = mx;
                    expbig = expy;
                    expsmall = expx;
                    sign_big = sy;
                    sign_small = sx;
                end

                delta = expbig - expsmall;
                smaller = shift_sticky(smaller, delta);
                sign_res = sign_big;

                if (sign_big == sign_small)
                    total = {1'b0,big} + {1'b0,smaller};
                else
                    total = {1'b0,big} - {1'b0,smaller};

                expout = expbig;

                if (total == 0) begin
                    answer = {(sx && sy), 31'b0};
                end else begin
                    if (total[27]) begin
                        norm = total[27:1];
                        norm[0] = norm[0] | total[0];
                        expout = expout + 1;
                    end else begin
                        norm = total[26:0];
                        for (j = 0; j < 26; j = j + 1) begin
                            if (!norm[26] && expout > 1) begin
                                norm = norm << 1;
                                expout = expout - 1;
                            end
                        end
                    end

                    fraction24 = norm[26:3];
                    guardbit = norm[2];
                    roundbit = norm[1];
                    stickybit = norm[0];

                    rounded = {1'b0, fraction24} +
                              (guardbit && (roundbit || stickybit || fraction24[0]));

                    if (rounded[24]) begin
                        fraction24 = rounded[24:1];
                        expout = expout + 1;
                    end else begin
                        fraction24 = rounded[23:0];
                    end

                    exp_field = expout[7:0];

                    if (expout >= 255)
                        answer = {sign_res, 8'hff, 23'b0};
                    else if (expout == 1 && !fraction24[23])
                        answer = {sign_res, 8'b0, fraction24[22:0]};
                    else
                        answer = {sign_res, exp_field, fraction24[22:0]};
                end
            end

            calculate = answer;
        end
    endfunction

    always_comb begin
        result = calculate(a, b, sub);
    end

endmodule


module fp_addsub (
    input logic clk, reset, in_valid, sub,
    input logic [31:0] a, b,
    output logic out_valid,
    output logic [31:0] result
);

    logic [31:0] core_result;

    (* keep_hierarchy = "yes" *)
    fp_addsub_core u_core (
        .a(a),
        .b(b),
        .sub(sub),
        .result(core_result)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 32'b0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid)
                result <= core_result;
        end
    end

endmodule
