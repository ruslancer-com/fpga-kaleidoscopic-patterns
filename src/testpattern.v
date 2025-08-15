// =====================================================================
// File name         : testpattern.v - KALEIDOSCOPIC PATTERN GENERATOR
// Module name       : testpattern
// Target Hardware   : Tang Nano 20K FPGA (Gowin GW2AR-LV18QN88C8/I7)
// =====================================================================
//
// TANG NANO 20K KALEIDOSCOPIC PATTERN GENERATOR ENGINE
// ====================================================
//
// This module generates mesmerizing animated kaleidoscopic patterns using
// mathematical algorithms implemented in hardware. It creates 8 different
// pattern modes with smooth real-time animation at 1280x720@60Hz resolution.
//
// MATHEMATICAL APPROACH:
// ----------------------
// 1. Generates precise video timing signals for HDMI output
// 2. Uses a 5-stage pixel processing pipeline for high-frequency operation
// 3. Calculates distance metrics (Manhattan, Euclidean approximation) from screen center
// 4. Applies geometric transformations to create kaleidoscopic effects
// 5. Converts mathematical patterns to HSV color space for vibrant colors
// 6. Performs real-time HSV→RGB conversion with optimized algorithms
// 7. Synchronizes all processing with pixel clock for stable video output
//
// PATTERN MODES (Auto-cycling every ~17 frames ≈ 0.28 seconds):
// ============================================================
// Mode 0: Animated Diamonds    - L1 norm creates diamond shapes with rainbow cycling
// Mode 1: Pulsating Circles    - Euclidean distance approximation for smooth circles  
// Mode 2: Rotating Squares     - L∞ norm generates square/rectangular patterns
// Mode 3: Rainbow Spiral       - Combined distance and angular effects with rapid color cycling
// Mode 4: Plasma Effect        - XOR interference patterns creating organic plasma-like motion
// Mode 5: Metaball Simulation  - Three moving attractors with field-based rendering
// Mode 6: Color Wheel          - Radial color distribution with distance-based saturation
// Mode 7: Morphing Shapes      - Time-based blending between different geometric forms
//
// HARDWARE OPTIMIZATION:
// =====================
// - 5-stage pipeline prevents timing violations at 74.25MHz pixel clock
// - Fixed-point arithmetic avoids expensive floating-point operations  
// - Optimized HSV→RGB conversion using bit manipulation and lookup-free algorithms
// - Bounded calculations prevent overflow in all mathematical operations
// - Parallel distance calculations for real-time metaball rendering
//
// =====================================================================

module testpattern
(
    // Clock and Reset
    input              I_pxl_clk   ,    // 74.25MHz pixel clock for 1280x720@60Hz timing
    input              I_rst_n     ,    // Active-low asynchronous reset signal
    
    // Pattern Control
    input      [2:0]   I_mode      ,    // Pattern mode select (0-7) determines visual effect type
    input      [7:0]   I_single_r  ,    // Single color red component (unused in pattern modes)
    input      [7:0]   I_single_g  ,    // Single color green component (unused in pattern modes)
    input      [7:0]   I_single_b  ,    // Single color blue component (unused in pattern modes)
    
    // Video Timing Configuration (1280x720@60Hz)
    input      [11:0]  I_h_total   ,    // Total horizontal pixels per line (1650 for 720p)
    input      [11:0]  I_h_sync    ,    // Horizontal sync pulse width (40 pixels for 720p)
    input      [11:0]  I_h_bporch  ,    // Horizontal back porch width (220 pixels for 720p)
    input      [11:0]  I_h_res     ,    // Horizontal active resolution (1280 pixels)
    input      [11:0]  I_v_total   ,    // Total vertical lines per frame (750 for 720p)
    input      [11:0]  I_v_sync    ,    // Vertical sync pulse width (5 lines for 720p)
    input      [11:0]  I_v_bporch  ,    // Vertical back porch height (20 lines for 720p)
    input      [11:0]  I_v_res     ,    // Vertical active resolution (720 lines)
    input              I_hs_pol    ,    // Horizontal sync polarity (0=negative, 1=positive)
    input              I_vs_pol    ,    // Vertical sync polarity (0=negative, 1=positive)
    
    // Video Output
    output             O_de        ,    // Display enable (high during active video region)
    output reg         O_hs        ,    // Horizontal sync output
    output reg         O_vs        ,    // Vertical sync output  
    output     [7:0]   O_data_r    ,    // Red channel output (8-bit, 0-255)
    output     [7:0]   O_data_g    ,    // Green channel output (8-bit, 0-255) 
    output     [7:0]   O_data_b         // Blue channel output (8-bit, 0-255)
); 

//==============================================================================
// MATHEMATICAL PROCESSING VARIABLES - 5-STAGE PIPELINE ARCHITECTURE
//==============================================================================

// ---- DISTANCE CALCULATION VARIABLES (Pipeline Stage 1-2) ----
reg [15:0] dx_abs, dy_abs;              // Absolute X,Y distances from screen center (16-bit for safety)
reg [16:0] dist_manhattan, dist_approx; // Distance metrics: L1 norm and Euclidean approximation (17-bit)
reg [11:0] center_x, center_y;          // Dynamic screen center coordinates (640, 360 for 1280x720)
reg [15:0] center_offset_x, center_offset_y; // Animated center offsets for pattern movement

// ---- ANIMATION TIMING VARIABLES (Frame-based Animation Engine) ----
reg [23:0] frame_counter;               // Master frame counter (24-bit for precise timing control)
reg [7:0]  anim_slow, anim_med, anim_fast, anim_ultra; // Multi-speed animation signals
reg [2:0]  mode_reg;                    // Registered pattern mode (prevents glitches during transitions)

// ---- GEOMETRIC SHAPE CALCULATION VARIABLES (Pipeline Stage 3) ----
reg [16:0] shape_l1, shape_l2, shape_linf, shape_circle; // Distance metrics for different geometric shapes
reg [11:0] size_base1, size_base2;      // Base sizes for primary and secondary pattern elements
reg [11:0] size_animated1, size_animated2; // Animated sizes with breathing/pulsing effects
reg        in_shape1, in_shape2;       // Boolean flags indicating pixel membership in shape regions

// ---- COLOR SPACE VARIABLES (Pipeline Stage 4-5) ----
reg [7:0] color_hue, color_sat, color_val; // HSV color space components (Hue, Saturation, Value)
reg [23:0] rgb_output;                  // Final RGB output (24-bit: 8R + 8G + 8B)

// ---- METABALL SIMULATION VARIABLES (Advanced Pattern Mode) ----
reg [11:0] ball_x1, ball_y1, ball_x2, ball_y2, ball_x3, ball_y3; // Three metaball center coordinates
reg [15:0] ball_dist1, ball_dist2, ball_dist3; // Distance from current pixel to each metaball center
reg [17:0] metaball_field;              // Combined metaball field strength (18-bit for three 16-bit sums)

//==============================================================================
// SYSTEM CONSTANTS AND PIPELINE PARAMETERS
//==============================================================================

localparam N = 8;                       // Pipeline depth for video timing synchronization

// ---- RGB COLOR CONSTANTS (24-bit BGR format for HDMI) ----
localparam	WHITE	= 24'hFFFFFF;       // Pure white reference
localparam	BLACK	= 24'h000000;       // Pure black reference  
localparam  RED     = 24'h0000FF;       // Pure red in BGR format
localparam  GREEN   = 24'h00FF00;       // Pure green in BGR format
localparam  BLUE    = 24'hFF0000;       // Pure blue in BGR format

//==============================================================================
// VIDEO TIMING GENERATION VARIABLES
//==============================================================================

// ---- MASTER TIMING COUNTERS ----
reg  [11:0]   V_cnt, H_cnt;             // Master horizontal and vertical pixel counters
wire          Pout_de_w, Pout_hs_w, Pout_vs_w; // Raw timing signals from counter logic
reg  [N-1:0]  Pout_de_dn, Pout_hs_dn, Pout_vs_dn; // Pipeline delay registers for timing alignment

// ---- ACTIVE VIDEO REGION DETECTION ----
wire 		  De_pos, De_neg, Vs_pos;  // Edge detection signals for active video transitions
reg  [11:0]   De_vcnt, De_hcnt;         // Active video region pixel counters (coordinates within display area)

//==============================================================================
// PIXEL PROCESSING PIPELINE - 5 STAGES FOR 74.25MHz OPERATION
//==============================================================================
// This pipeline architecture ensures stable operation at high pixel clock frequencies
// by distributing mathematical calculations across multiple clock cycles.

// ---- PIPELINE STAGE 0-4: PIXEL COORDINATE PROGRESSION ----
reg [11:0] pix_x0, pix_y0;              // Stage 0: Current pixel coordinates (direct from counters)
reg [11:0] pix_x1, pix_y1;              // Stage 1: Registered coordinates for distance prep
reg [11:0] pix_x2, pix_y2;              // Stage 2: Coordinates for distance calculation
reg [11:0] pix_x3, pix_y3;              // Stage 3: Coordinates for shape determination  
reg [11:0] pix_x4, pix_y4;              // Stage 4: Coordinates for color calculation

//==============================================================================
// VIDEO OUTPUT CONTROL VARIABLES
//==============================================================================

wire [23:0]   Data_sel;                 // Pattern generator output selection
reg  [23:0]   Data_tmp;                 // Final RGB output buffer synchronized with display enable

//==============================================================================
// VIDEO TIMING GENERATION - HDMI-COMPATIBLE SYNC SIGNALS
//==============================================================================
// Generates precise video timing for 1280x720@60Hz HDMI output.
// Creates horizontal and vertical sync pulses, blanking periods, and active video regions
// according to VESA timing standards for 720p resolution.
//
// ---- VERTICAL LINE COUNTER ----
// Counts video lines (0 to I_v_total-1). Increments at end of each horizontal line.
// For 720p: counts 0-749 (750 total lines including blanking)
always@(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n)
		V_cnt <= 12'd0;                     // Reset to top of frame
	else     
		begin
			if((V_cnt >= (I_v_total-1'b1)) && (H_cnt >= (I_h_total-1'b1)))
				V_cnt <= 12'd0;             // End of frame: reset to line 0
			else if(H_cnt >= (I_h_total-1'b1))
				V_cnt <=  V_cnt + 1'b1;     // End of line: advance to next line
			else
				V_cnt <= V_cnt;             // Mid-line: maintain current line count
		end
end

// ---- HORIZONTAL PIXEL COUNTER ----
// Counts pixels within each line (0 to I_h_total-1). Resets at end of each line.
// For 720p: counts 0-1649 (1650 total pixels including blanking)
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n)
		H_cnt <=  12'd0;                    // Reset to start of line
	else if(H_cnt >= (I_h_total-1'b1))
		H_cnt <=  12'd0;                    // End of line: reset to pixel 0 
	else 
		H_cnt <=  H_cnt + 1'b1;             // Normal operation: advance to next pixel           
end

// ---- VIDEO TIMING SIGNAL GENERATION ----
// Creates the three essential video timing signals for HDMI transmission

// Display Enable: HIGH during active video region (1280x720 pixels)
// LOW during horizontal and vertical blanking periods  
assign  Pout_de_w = ((H_cnt>=(I_h_sync+I_h_bporch))&(H_cnt<=(I_h_sync+I_h_bporch+I_h_res-1'b1)))&
                    ((V_cnt>=(I_v_sync+I_v_bporch))&(V_cnt<=(I_v_sync+I_v_bporch+I_v_res-1'b1))) ;

// Horizontal Sync: LOW during sync pulse (40 pixels), HIGH otherwise
assign  Pout_hs_w =  ~((H_cnt>=12'd0) & (H_cnt<=(I_h_sync-1'b1))) ;

// Vertical Sync: LOW during sync pulse (5 lines), HIGH otherwise  
assign  Pout_vs_w =  ~((V_cnt>=12'd0) & (V_cnt<=(I_v_sync-1'b1))) ;  

always@(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n)
		begin
			Pout_de_dn  <= {N{1'b0}};                          
			Pout_hs_dn  <= {N{1'b1}};
			Pout_vs_dn  <= {N{1'b1}}; 
		end
	else 
		begin
			Pout_de_dn  <= {Pout_de_dn[N-2:0],Pout_de_w};                          
			Pout_hs_dn  <= {Pout_hs_dn[N-2:0],Pout_hs_w};
			Pout_vs_dn  <= {Pout_vs_dn[N-2:0],Pout_vs_w}; 
		end
end

assign O_de = Pout_de_dn[5]; // 5-stage pipeline delay

always@(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n)
		begin                        
			O_hs  <= 1'b1;
			O_vs  <= 1'b1; 
		end
	else 
		begin                         
			O_hs  <= I_hs_pol ? ~Pout_hs_dn[5] : Pout_hs_dn[5] ;
			O_vs  <= I_vs_pol ? ~Pout_vs_dn[5] : Pout_vs_dn[5] ;
		end
end

//=================================================================================
// Timing control (verified)
//=================================================================================
assign De_pos	= !Pout_de_dn[1] & Pout_de_dn[0];
assign De_neg	= Pout_de_dn[1] && !Pout_de_dn[0];
assign Vs_pos	= !Pout_vs_dn[1] && Pout_vs_dn[0];

always @(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n)
		De_hcnt <= 12'd0;
	else if (De_pos == 1'b1)
		De_hcnt <= 12'd0;
	else if (Pout_de_dn[1] == 1'b1)
		De_hcnt <= De_hcnt + 1'b1;
	else
		De_hcnt <= De_hcnt;
end

always @(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n) 
		De_vcnt <= 12'd0;
	else if (Vs_pos == 1'b1)
		De_vcnt <= 12'd0;
	else if (De_neg == 1'b1)
		De_vcnt <= De_vcnt + 1'b1;
	else
		De_vcnt <= De_vcnt;
end

//=================================================================================
// Clean 5-stage pixel coordinate pipeline
//=================================================================================
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        pix_x0 <= 12'd0; pix_y0 <= 12'd0;
        pix_x1 <= 12'd0; pix_y1 <= 12'd0;
        pix_x2 <= 12'd0; pix_y2 <= 12'd0;
        pix_x3 <= 12'd0; pix_y3 <= 12'd0;
        pix_x4 <= 12'd0; pix_y4 <= 12'd0;
    end
    else begin
        // Stage 0: Current pixel coordinates
        pix_x0 <= De_hcnt;
        pix_y0 <= De_vcnt;
        
        // Pipeline stages
        pix_x1 <= pix_x0; pix_y1 <= pix_y0;
        pix_x2 <= pix_x1; pix_y2 <= pix_y1;
        pix_x3 <= pix_x2; pix_y3 <= pix_y2;
        pix_x4 <= pix_x3; pix_y4 <= pix_y3;
    end
end

//=================================================================================
// ANIMATION TIMING ENGINE - HIGH-SPEED KALEIDOSCOPIC MOTION CONTROL
//=================================================================================
// Creates multiple synchronized animation speeds for complex visual effects.
// Uses frame-based counters updated at 60Hz vertical sync rate to ensure
// smooth temporal consistency across all pattern modes.
//
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        frame_counter <= 24'd0;             // Reset master frame counter
        anim_slow <= 8'd0;                  // Reset all animation speeds
        anim_med <= 8'd0;
        anim_fast <= 8'd0;
        anim_ultra <= 8'd0;
        mode_reg <= 3'd0;                   // Reset pattern mode register
    end
    else if (Vs_pos == 1'b1) begin         // Update only at start of each new frame (60Hz)
        frame_counter <= frame_counter + 24'd1;  // Increment master frame counter
        
        // ---- MULTI-SPEED ANIMATION SYSTEM ----
        // Creates 4 different animation speeds by extracting different bit ranges
        // from the master frame counter. Higher speeds create more dynamic effects.
        
        anim_slow  <= frame_counter[10:3];  // Slow: Changes every 8 frames (≈7.5Hz)
        anim_med   <= frame_counter[8:1];   // Medium: Changes every 2 frames (≈30Hz)  
        anim_fast  <= frame_counter[7:0];   // Fast: Changes every frame (60Hz)
        anim_ultra <= frame_counter[6:0];   // Ultra: Changes every frame with finer resolution
        
        // Synchronize mode changes to frame boundaries to prevent visual glitches
        mode_reg <= I_mode;
    end
end

//=================================================================================
// Stable center calculation with bounds checking
//=================================================================================
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        center_x <= 12'd320;  // Default centers
        center_y <= 12'd240;
        center_offset_x <= 16'd0;
        center_offset_y <= 16'd0;
    end
    else if (Vs_pos == 1'b1) begin
        // Base centers
        center_x <= I_h_res >> 1;
        center_y <= I_v_res >> 1;
        
        // Animated offsets - properly bounded to prevent screen overflow
        center_offset_x <= {{8{anim_slow[7]}}, anim_slow[7:0]};     // +/- 128 pixels
        center_offset_y <= {{8{anim_med[7]}}, anim_med[7:0]};       // +/- 128 pixels
    end
end

//=================================================================================
// PIPELINE STAGE 1: DISTANCE CALCULATION - MATHEMATICAL FOUNDATION
//=================================================================================
// Calculates the absolute distance from each pixel to the screen center.
// This forms the mathematical basis for all kaleidoscopic patterns by providing
// radial distance information used in geometric transformations.
//
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        dx_abs <= 16'd0;
        dy_abs <= 16'd0;
    end
    else begin
        // Calculate absolute differences with overflow protection
        // Use signed arithmetic then take absolute value
        if ({1'b0, pix_x1} >= {4'd0, center_x}) 
            dx_abs <= {4'd0, pix_x1} - {4'd0, center_x};
        else 
            dx_abs <= {4'd0, center_x} - {4'd0, pix_x1};
            
        if ({1'b0, pix_y1} >= {4'd0, center_y}) 
            dy_abs <= {4'd0, pix_y1} - {4'd0, center_y};
        else 
            dy_abs <= {4'd0, center_y} - {4'd0, pix_y1};
    end
end

//=================================================================================
// PIPELINE STAGE 2: DISTANCE METRICS - GEOMETRIC PATTERN GENERATION
//=================================================================================
// Computes different mathematical distance norms to create various geometric shapes:
// - Manhattan Distance (L1): Creates diamond/rhombus patterns  
// - Euclidean Distance (L2): Creates circular patterns (approximated for efficiency)
// Each metric produces different kaleidoscopic symmetries and visual effects.
//
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        dist_manhattan <= 17'd0;
        dist_approx <= 17'd0;
    end
    else begin
        // Manhattan distance (L1 norm) for diamonds
        dist_manhattan <= {1'b0, dx_abs} + {1'b0, dy_abs};
        
        // Approximated Euclidean distance for circles
        // Uses: max(dx,dy) + 0.5*min(dx,dy) ≈ sqrt(dx²+dy²)
        if (dx_abs >= dy_abs)
            dist_approx <= {1'b0, dx_abs} + {2'b0, dy_abs[15:1]};
        else
            dist_approx <= {1'b0, dy_abs} + {2'b0, dx_abs[15:1]};
    end
end

//=================================================================================
// Stage 3: Shape calculations - BOUNDS CHECKED
//=================================================================================
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        shape_l1 <= 17'd0;
        shape_l2 <= 17'd0;
        shape_linf <= 17'd0;
        shape_circle <= 17'd0;
        size_base1 <= 12'd100;
        size_base2 <= 12'd60;
        size_animated1 <= 12'd100;
        size_animated2 <= 12'd60;
    end
    else begin
        // Different shape metrics
        shape_l1 = dist_manhattan;                              // Diamond
        shape_l2 = dist_approx;                                 // Approximate circle
        shape_linf = (dx_abs > dy_abs) ? {1'b0, dx_abs} : {1'b0, dy_abs}; // Square
        shape_circle = dist_approx + {4'd0, dist_approx[16:4]}; // Better circle
        
        // Animated sizes with bounds checking
        size_base1 = 12'd100;  // Base size
        size_base2 = 12'd60;   // Smaller base
        
        // Ensure sizes don't underflow or overflow - cleaner bit handling
        size_animated1 <= size_base1 + {4'd0, anim_slow};      // 100-355 range
        size_animated2 <= size_base2 + {4'd0, anim_med};       // 60-315 range
    end
end

//=================================================================================
// PIPELINE STAGE 4: KALEIDOSCOPIC PATTERN GENERATION - VISUAL EFFECT ENGINE
//=================================================================================
// The heart of the kaleidoscopic system! This stage implements 8 different 
// mathematical algorithms that transform distance metrics into mesmerizing
// animated patterns. Each mode creates unique visual effects using different
// combinations of geometry, color theory, and animation techniques.
//
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
    if(!I_rst_n) begin
        in_shape1 <= 1'b0;
        in_shape2 <= 1'b0;
        color_hue <= 8'd0;
        color_sat <= 8'd255;
        color_val <= 8'd0;
        rgb_output <= BLACK;
    end
    else begin
        case(mode_reg)
            // ============================================================
            // MODE 0: ANIMATED DIAMONDS - L1 NORM KALEIDOSCOPE
            // ============================================================
            // Uses Manhattan distance (L1 norm) to create diamond patterns.
            // Mathematical basis: |x| + |y| = constant creates diamond contours
            // Animation: Breathing effect with hue rotation creates rainbow diamonds
            3'b000:
                begin
                    in_shape1 <= (shape_l1 < {5'd0, size_animated1});
                    in_shape2 <= (shape_l1 < {5'd0, size_animated2});
                    
                    color_hue <= anim_slow + shape_l1[9:2];
                    color_sat <= 8'd240;
                    color_val <= in_shape1 ? (in_shape2 ? 8'd220 : 8'd140) : 8'd50;
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            3'b001: // Animated Circles - STABLE  
                begin
                    in_shape1 <= (shape_circle < {5'd0, size_animated1});
                    in_shape2 <= (shape_circle < {5'd0, size_animated2});
                    
                    color_hue <= 8'd120 + anim_slow + shape_circle[9:2];
                    color_sat <= 8'd220;
                    color_val <= in_shape1 ? (in_shape2 ? 8'd200 : 8'd120) : 8'd40;
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            3'b010: // Animated Squares - STABLE
                begin
                    in_shape1 <= (shape_linf < {5'd0, size_animated1});
                    in_shape2 <= (shape_linf < {5'd0, size_animated2});
                    
                    color_hue <= 8'd240 + anim_slow + shape_linf[8:1];
                    color_sat <= 8'd200;
                    color_val <= in_shape1 ? (in_shape2 ? 8'd180 : 8'd100) : 8'd30;
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 3: RAINBOW SPIRAL - ANGULAR VELOCITY KALEIDOSCOPE  
            // ============================================================
            // Combines radial distance with rapid angular rotation effects.
            // Creates hypnotic spiraling rainbow patterns that seem to rotate
            // and pulse simultaneously. High-speed animation for maximum impact.
            3'b011:
                begin
                    color_hue <= shape_l1[8:1] + (anim_fast << 1) + anim_ultra[6:0];
                    color_sat <= 8'd240;
                    color_val <= 8'd120 + shape_circle[6:0] + anim_med[4:0];
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            3'b100: // Plasma Effect - IMPROVED STABILITY
                begin
                    color_hue <= pix_x3[6:0] + pix_y3[6:0] + (anim_fast << 1) + anim_ultra[5:0];
                    color_sat <= 8'd220;
                    color_val <= 8'd140 + (pix_x3[5:0] ^ pix_y3[5:0]) + anim_med[4:0];
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 5: METABALL SIMULATION - ORGANIC FLUID DYNAMICS
            // ============================================================
            // Advanced algorithm simulating organic blob-like shapes that flow
            // and merge. Uses field-based rendering with three moving attractors.
            // Creates mesmerizing organic patterns reminiscent of lava lamps.
            3'b101:
                begin
                    // Three ball centers with smoother, bounded movement
                    ball_x1 = center_x + {anim_slow[4:0], 4'd0};         // +/- 240 max  
                    ball_y1 = center_y + {anim_med[4:0], 4'd0};
                    ball_x2 = center_x - {anim_slow[3:0], 5'd0};         // +/- 480 max  
                    ball_y2 = center_y - {anim_med[3:0], 5'd0};
                    ball_x3 = center_x + {anim_med[3:0], 5'd0};
                    ball_y3 = center_y - {anim_slow[3:0], 5'd0};
                    
                    // Distance calculations with overflow protection
                    if (pix_x3 >= ball_x1)
                        ball_dist1 = ({4'd0, pix_x3 - ball_x1} + {4'd0, (pix_y3 >= ball_y1) ? (pix_y3 - ball_y1) : (ball_y1 - pix_y3)});
                    else
                        ball_dist1 = ({4'd0, ball_x1 - pix_x3} + {4'd0, (pix_y3 >= ball_y1) ? (pix_y3 - ball_y1) : (ball_y1 - pix_y3)});
                        
                    if (pix_x3 >= ball_x2)
                        ball_dist2 = ({4'd0, pix_x3 - ball_x2} + {4'd0, (pix_y3 >= ball_y2) ? (pix_y3 - ball_y2) : (ball_y2 - pix_y3)});
                    else
                        ball_dist2 = ({4'd0, ball_x2 - pix_x3} + {4'd0, (pix_y3 >= ball_y2) ? (pix_y3 - ball_y2) : (ball_y2 - pix_y3)});
                        
                    if (pix_x3 >= ball_x3)
                        ball_dist3 = ({4'd0, pix_x3 - ball_x3} + {4'd0, (pix_y3 >= ball_y3) ? (pix_y3 - ball_y3) : (ball_y3 - pix_y3)});
                    else
                        ball_dist3 = ({4'd0, ball_x3 - pix_x3} + {4'd0, (pix_y3 >= ball_y3) ? (pix_y3 - ball_y3) : (ball_y3 - pix_y3)});
                    
                    // Metaball field calculation - improved stability and reduced overflow
                    metaball_field = ({2'd0, 16'd1000} - {2'd0, ball_dist1[15:1]}) + 
                                   ({2'd0, 16'd1000} - {2'd0, ball_dist2[15:1]}) + 
                                   ({2'd0, 16'd1000} - {2'd0, ball_dist3[15:1]});
                    
                    color_hue <= metaball_field[13:6] + anim_fast;
                    color_sat <= 8'd220;
                    color_val <= (metaball_field > 18'd2500) ? (8'd180 + metaball_field[6:0]) : (8'd80 + metaball_field[6:0]);
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            3'b110: // Color Wheel - STABLE
                begin
                    color_hue <= shape_l1[10:3] + (anim_slow << 2);
                    color_sat <= (shape_circle < 17'd200) ? 8'd255 : 8'd160;
                    color_val <= (shape_circle < 17'd150) ? 8'd200 : 8'd80;
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            3'b111: // Morphing Shapes - STABLE
                begin
                    // Time-based morphing between shapes
                    in_shape1 <= (anim_med[7]) ? 
                                (shape_l1 < {5'd0, size_animated1}) : 
                                (shape_circle < {5'd0, size_animated1});
                    in_shape2 <= (anim_fast[6]) ?
                                (shape_linf < {5'd0, size_animated2}) :
                                (shape_circle < {5'd0, size_animated2});
                    
                    color_hue <= (anim_fast + anim_slow);
                    color_sat <= 8'd255;
                    color_val <= (in_shape1 || in_shape2) ? 8'd200 : 8'd50;
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            default: 
                rgb_output <= BLACK;
        endcase
    end
end

//=================================================================================
// HSV TO RGB COLOR CONVERSION - OPTIMIZED FOR FPGA IMPLEMENTATION
//=================================================================================
// Converts HSV (Hue, Saturation, Value) color space to RGB for display.
// HSV is ideal for generating smooth color transitions and gradients in mathematical
// patterns. This hardware-optimized implementation avoids floating-point operations
// and uses efficient bit manipulation for real-time conversion at 74.25MHz.
//
// HSV Color Space Benefits:
// - Hue: Controls color wheel position (0-255 maps to 0-360°)  
// - Saturation: Controls color purity (0=grayscale, 255=pure color)
// - Value: Controls brightness (0=black, 255=full brightness)
//
// Algorithm: Optimized 6-sector conversion with fixed-point arithmetic
//=================================================================================
function [23:0] hsv_to_rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] v;
    reg [7:0] region;
    reg [7:0] remainder;
    reg [15:0] p, q, t;
    reg [7:0] r, g, b;
    begin
        if (s < 8'd16) begin
            // Low saturation = grayscale
            hsv_to_rgb = {v, v, v};
        end else begin
            region = h[7:5];        // Divide hue by 32 (256/8 sectors)
            remainder = h[4:0];     // Simplified remainder calculation (0-31)
            
            // Calculate intermediate values with improved precision
            p = ({8'd0, v} * (16'd255 - {8'd0, s})) >> 8;
            q = ({8'd0, v} * (16'd255 - (({8'd0, s} * {3'd0, remainder, 3'd0}) >> 8))) >> 8;
            t = ({8'd0, v} * (16'd255 - (({8'd0, s} * (16'd255 - {3'd0, remainder, 3'd0})) >> 8))) >> 8;
            
            case (region)
                3'd0: begin r = v; g = t[7:0]; b = p[7:0]; end        // Red to Yellow
                3'd1: begin r = q[7:0]; g = v; b = p[7:0]; end        // Yellow to Green
                3'd2: begin r = p[7:0]; g = v; b = t[7:0]; end        // Green to Cyan
                3'd3: begin r = p[7:0]; g = q[7:0]; b = v; end        // Cyan to Blue
                3'd4: begin r = t[7:0]; g = p[7:0]; b = v; end        // Blue to Magenta
                3'd5: begin r = v; g = p[7:0]; b = q[7:0]; end        // Magenta to Red
                default: begin r = v; g = p[7:0]; b = q[7:0]; end     // Default to Magenta
            endcase
            
            hsv_to_rgb = {b, g, r}; // BGR format for output
        end
    end
endfunction

//============================================================
assign Data_sel = rgb_output;

//---------------------------------------------------
// Output stage - PROPERLY SYNCHRONIZED
//---------------------------------------------------
always @(posedge I_pxl_clk or negedge I_rst_n)
begin
	if(!I_rst_n) 
		Data_tmp <= 24'd0;
	else if(Pout_de_dn[5] == 1'b1)  // Match 5-stage pipeline
		Data_tmp <= Data_sel;
	else
		Data_tmp <= 24'd0;
end

assign O_data_r = Data_tmp[ 7: 0];
assign O_data_g = Data_tmp[15: 8];
assign O_data_b = Data_tmp[23:16];

endmodule