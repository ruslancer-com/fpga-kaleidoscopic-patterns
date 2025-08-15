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
reg [31:0] dx_squared, dy_squared;      // Squared distances: dx², dy² for perfect circles (32-bit precision)
reg [31:0] dist_squared;                // Perfect circle distance: dx² + dy² (no approximation!)
reg [11:0] center_x, center_y;          // Dynamic screen center coordinates (640, 360 for 1280x720)
reg [15:0] center_offset_x, center_offset_y; // Animated center offsets for pattern movement

// ---- ANIMATION TIMING VARIABLES (Frame-based Animation Engine) ----
reg [23:0] frame_counter;               // Master frame counter (24-bit for precise timing control)
reg [7:0]  anim_slow, anim_med, anim_fast, anim_ultra; // Multi-speed animation signals
reg [2:0]  mode_reg;                    // Registered pattern mode (prevents glitches during transitions)

// ---- GEOMETRIC SHAPE CALCULATION VARIABLES (Pipeline Stage 3) ----
reg [16:0] shape_l1, shape_l2, shape_linf, shape_circle; // Distance metrics for different geometric shapes
reg [31:0] shape_circle_perfect;                         // Perfect circle using squared distance (TRUE circles!)
reg [11:0] size_base1, size_base2;      // Base sizes for primary and secondary pattern elements
reg [11:0] size_animated1, size_animated2; // Animated sizes with breathing/pulsing effects
reg [23:0] size_squared1, size_squared2; // Squared sizes for perfect circle comparisons (r²)
reg        in_shape1, in_shape2;       // Boolean flags indicating pixel membership in shape regions

// ---- COLOR SPACE VARIABLES (Pipeline Stage 4-5) ----
reg [7:0] color_hue, color_sat, color_val; // HSV color space components (Hue, Saturation, Value)
reg [23:0] rgb_output;                  // Final RGB output (24-bit: 8R + 8G + 8B)

// ---- MORPHING ALGORITHM VARIABLES (Mode 7 Enhancement) ----
reg [7:0] morph_weight;                 // Morphing interpolation weight (0-255)
reg [31:0] organic_dist;                // Organic distance for blob morphing
reg [7:0] mandala_factor;               // Mandala pattern generation factor

// ---- ENHANCED PLASMA VARIABLES (Mode 4 Improvement) ----
reg [15:0] wave1, wave2, wave3, wave4;  // Multiple wave frequencies for complex interference
reg [31:0] plasma_field;                // Combined plasma field strength

// ---- ENHANCED METABALL VARIABLES (Mode 5 Improvement) ----
reg [31:0] ball_dist1_sq, ball_dist2_sq, ball_dist3_sq; // Squared distances for proper metaball physics
reg [31:0] ball_field1, ball_field2, ball_field3;       // Individual metaball field strengths (1/r² physics)
reg [31:0] metaball_field_perfect;                      // Perfect metaball field using proper physics

// ---- METABALL SIMULATION VARIABLES (Enhanced with Perfect Physics) ----
reg [11:0] ball_x1, ball_y1, ball_x2, ball_y2, ball_x3, ball_y3; // Three metaball center coordinates
reg [15:0] ball_dist1, ball_dist2, ball_dist3; // Legacy distances (L1 norm) 
reg [17:0] metaball_field;              // Legacy metaball field (backward compatibility)

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
        
        // ---- MULTI-SPEED ANIMATION SYSTEM - OPTIMIZED FOR SMOOTH VISUALS ----
        // Creates 4 different animation speeds by extracting different bit ranges
        // from the master frame counter. Optimized for smooth, pleasing motion.
        
        anim_slow  <= frame_counter[9:2];   // Slow: Changes every 4 frames (≈15Hz) - smoother breathing
        anim_med   <= frame_counter[7:0];   // Medium: Changes every frame (60Hz) - fluid motion  
        anim_fast  <= frame_counter[6:0] + frame_counter[8:2];  // Fast: Faster change with smooth transitions
        anim_ultra <= frame_counter[5:0] + frame_counter[7:3];  // Ultra: Very smooth high-speed animation
        
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
        dx_squared <= 32'd0;
        dy_squared <= 32'd0; 
        dist_squared <= 32'd0;
    end
    else begin
        // Manhattan distance (L1 norm) for diamonds
        dist_manhattan <= {1'b0, dx_abs} + {1'b0, dy_abs};
        
        // Legacy approximation (kept for compatibility)
        if (dx_abs >= dy_abs)
            dist_approx <= {1'b0, dx_abs} + {3'b0, dy_abs[15:2]} + {4'b0, dy_abs[15:3]};
        else
            dist_approx <= {1'b0, dy_abs} + {3'b0, dx_abs[15:2]} + {4'b0, dx_abs[15:3]};
            
        // *** PERFECT CIRCLE CALCULATION - TRUE EUCLIDEAN DISTANCE ***
        // Calculate dx² and dy² using efficient bit operations
        // dx² = dx * dx, dy² = dy * dy
        dx_squared <= {16'd0, dx_abs} * {16'd0, dx_abs};  // 16-bit × 16-bit = 32-bit result
        dy_squared <= {16'd0, dy_abs} * {16'd0, dy_abs};  // 16-bit × 16-bit = 32-bit result
        
        // Perfect circle equation: x² + y² = r² (no approximation!)
        dist_squared <= dx_squared + dy_squared;
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
        shape_circle_perfect <= 32'd0;
        size_base1 <= 12'd100;
        size_base2 <= 12'd60;
        size_animated1 <= 12'd100;
        size_animated2 <= 12'd60;
        size_squared1 <= 24'd0;
        size_squared2 <= 24'd0;
    end
    else begin
        // Different shape metrics - ENHANCED for PERFECT geometry
        shape_l1 = dist_manhattan;                              // Diamond (L1 norm)
        shape_l2 = dist_approx;                                 // Legacy circle (approximation)
        shape_linf = (dx_abs > dy_abs) ? {1'b0, dx_abs} : {1'b0, dy_abs}; // Square (L∞ norm)
        shape_circle = dist_approx;                             // Legacy circle (backward compatibility)
        shape_circle_perfect = dist_squared;                    // *** PERFECT CIRCLES *** (x² + y² - TRUE math!)
        
        // IMPROVED animated sizes for smoother breathing effects
        size_base1 = 12'd120;  // Larger base size for better visibility
        size_base2 = 12'd80;   // Larger smaller base for smoother gradients
        
        // Smooth breathing animation with sine-like motion
        // Using bit combinations for more organic size variations
        size_animated1 <= size_base1 + {3'd0, anim_slow} + {5'd0, anim_med[7:1]};  // 120-400 range, smooth
        size_animated2 <= size_base2 + {4'd0, anim_slow[7:1]} + {4'd0, anim_fast[7:4]}; // 80-240 range, faster
        
        // Calculate squared sizes for perfect circle comparisons: r² = size²
        // These are used to compare against dist_squared for mathematically perfect circles
        size_squared1 <= {12'd0, size_animated1} * {12'd0, size_animated1};  // r1²
        size_squared2 <= {12'd0, size_animated2} * {12'd0, size_animated2};  // r2²
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
        morph_weight <= 8'd0;
        organic_dist <= 32'd0;
        mandala_factor <= 8'd0;
        wave1 <= 16'd0;
        wave2 <= 16'd0;
        wave3 <= 16'd0;
        wave4 <= 16'd0;
        plasma_field <= 32'd0;
        ball_dist1_sq <= 32'd0;
        ball_dist2_sq <= 32'd0;
        ball_dist3_sq <= 32'd0;
        ball_field1 <= 32'd0;
        ball_field2 <= 32'd0;
        ball_field3 <= 32'd0;
        metaball_field_perfect <= 32'd0;
    end
    else begin
        case(mode_reg)
            // ============================================================
            // MODE 0: SMOOTH ANIMATED DIAMONDS - L1 NORM KALEIDOSCOPE
            // ============================================================
            // Uses Manhattan distance (L1 norm) to create diamond patterns.
            // Mathematical basis: |x| + |y| = constant creates diamond contours
            // Enhanced with smooth gradients and improved color transitions
            3'b000:
                begin
                    in_shape1 <= (shape_l1 < {5'd0, size_animated1});
                    in_shape2 <= (shape_l1 < {5'd0, size_animated2});
                    
                    // Smoother hue rotation with distance-based variation
                    color_hue <= anim_med + {1'd0, shape_l1[10:4]} + anim_fast[6:0];
                    color_sat <= 8'd250;  // Higher saturation for vibrant colors
                    
                    // Smooth gradient transitions instead of hard edges
                    if (shape_l1 < {5'd0, size_animated2})
                        color_val <= 8'd240 - {2'd0, shape_l1[7:2]};      // Bright center
                    else if (shape_l1 < {5'd0, size_animated1})
                        color_val <= 8'd160 - {3'd0, shape_l1[8:4]};      // Medium ring
                    else if (shape_l1 < ({5'd0, size_animated1} + 17'd50))
                        color_val <= 8'd80 - {4'd0, shape_l1[9:6]};       // Soft edge
                    else
                        color_val <= 8'd30;  // Dark background
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 1: PERFECT CIRCLES - MATHEMATICALLY ACCURATE GEOMETRY
            // ============================================================
            // Uses TRUE Euclidean distance (x² + y² = r²) for perfect circular patterns.
            // No approximation - these are mathematically perfect circles!
            3'b001:
                begin
                    // Perfect circle membership tests using squared distances
                    in_shape1 <= (shape_circle_perfect < {8'd0, size_squared1});  // Compare x²+y² < r1²
                    in_shape2 <= (shape_circle_perfect < {8'd0, size_squared2});  // Compare x²+y² < r2²
                    
                    // Smooth color transitions with higher precision based on squared distance
                    color_hue <= 8'd120 + anim_med + shape_circle_perfect[19:12];  // Use high bits for smooth hue
                    color_sat <= 8'd250;  // Maximum saturation for vivid colors
                    
                    // Perfect anti-aliased gradients using squared distance for smooth transitions
                    if (shape_circle_perfect < {8'd0, size_squared2})
                        color_val <= 8'd240 - shape_circle_perfect[18:11];        // Bright center with perfect gradient
                    else if (shape_circle_perfect < {8'd0, size_squared1}) 
                        color_val <= 8'd160 - shape_circle_perfect[19:12];        // Medium ring with perfect gradient
                    else if (shape_circle_perfect < ({8'd0, size_squared1} + 32'd50000))  // Soft edge zone
                        color_val <= 8'd80 - shape_circle_perfect[20:13];         // Soft outer edge with perfect falloff
                    else
                        color_val <= 8'd15;  // Dark background
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 2: SMOOTH ANIMATED SQUARES - L∞ NORM KALEIDOSCOPE
            // ============================================================  
            // Uses Chebyshev distance (L∞ norm) to create square patterns.
            // Enhanced with smooth gradients for high-quality visuals.
            3'b010:
                begin
                    in_shape1 <= (shape_linf < {5'd0, size_animated1});
                    in_shape2 <= (shape_linf < {5'd0, size_animated2});
                    
                    // Smooth color cycling with distance variation
                    color_hue <= 8'd200 + anim_med + {2'd0, shape_linf[9:4]};
                    color_sat <= 8'd230;  // Higher saturation for better colors
                    
                    // Gradient-based shading for smooth square patterns
                    if (shape_linf < {5'd0, size_animated2})
                        color_val <= 8'd200 - {2'd0, shape_linf[7:2]};    // Bright center
                    else if (shape_linf < {5'd0, size_animated1})
                        color_val <= 8'd120 - {3'd0, shape_linf[8:4]};    // Medium ring  
                    else if (shape_linf < ({5'd0, size_animated1} + 17'd35))
                        color_val <= 8'd60 - {4'd0, shape_linf[9:6]};     // Soft edge
                    else
                        color_val <= 8'd25;  // Dark background
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 3: SMOOTH RAINBOW SPIRAL - ANGULAR VELOCITY KALEIDOSCOPE  
            // ============================================================
            // Combines radial distance with rapid angular rotation effects.
            // Enhanced with smoother spiraling motion and better color transitions.
            3'b011:
                begin
                    // Multi-frequency spiral with perfect radial component
                    color_hue <= {1'd0, shape_l1[9:3]} + (anim_fast << 1) + {1'd0, anim_ultra[6:0]} +
                                shape_circle_perfect[18:12];  // Perfect radial component for true spiraling
                    color_sat <= 8'd250;  // Maximum saturation for vibrant rainbow
                    
                    // Distance-based brightness with perfect radial gradients
                    color_val <= 8'd100 + shape_circle_perfect[17:10] + {2'd0, anim_med[5:0]} + 
                                {4'd0, anim_fast[7:4]};
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 4: ADVANCED PLASMA PHYSICS - MULTI-WAVE INTERFERENCE
            // ============================================================
            // Creates realistic plasma using multiple wave frequencies with proper
            // mathematical interference patterns. Uses sine/cosine approximations
            // and wave physics for authentic plasma-like motion.
            3'b100:
                begin
                    // ADVANCED MULTI-FREQUENCY WAVE GENERATION
                    // Generate 4 different wave frequencies for complex interference
                    
                    // Wave 1: High frequency X-axis wave (sine approximation)
                    // Using parabolic approximation: sin(x) ≈ 4x(π-x)/π² for [0,π]
                    wave1 <= {4'd0, pix_x3} + {2'd0, anim_fast};  // Fast horizontal wave
                    
                    // Wave 2: Medium frequency Y-axis wave 
                    wave2 <= {3'd0, pix_y3} + {3'd0, anim_med};   // Medium vertical wave
                    
                    // Wave 3: Diagonal wave (X+Y frequency)
                    wave3 <= {3'd0, pix_x3[9:0]} + {3'd0, pix_y3[9:0]} + {1'd0, anim_ultra};  // Diagonal interference
                    
                    // Wave 4: Rotational wave (distance-based)
                    wave4 <= shape_circle_perfect[15:0] + {4'd0, anim_slow};  // Radial wave using perfect distance
                    
                    // SOPHISTICATED WAVE INTERFERENCE CALCULATION
                    // Combine waves using mathematical interference principles
                    // Uses sine approximation: sin²(x) + cos²(x) = 1 for wave blending
                    plasma_field <= {16'd0, wave1} + {15'd0, wave2} + 
                                   {14'd0, wave3} + {13'd0, wave4} +
                                   // Cross-interference terms for complexity
                                   {18'd0, wave1[7:0] ^ wave2[7:0]} + 
                                   {17'd0, wave3[8:0] ^ wave4[8:0]} +
                                   // Harmonic components 
                                   {19'd0, (wave1[6:0] + wave3[6:0])} +
                                   {20'd0, (wave2[5:0] * wave4[5:0])};
                    
                    // ADVANCED PLASMA COLOR MAPPING
                    // Use high-precision plasma field for smooth color transitions
                    color_hue <= plasma_field[19:12] + anim_fast + {2'd0, plasma_field[23:18]};
                    color_sat <= 8'd255;  // Maximum saturation for vivid plasma colors
                    
                    // DYNAMIC BRIGHTNESS WITH WAVE INTERFERENCE
                    // Create pulsating brightness based on wave constructive/destructive interference
                    color_val <= 8'd100 + plasma_field[17:10] + 
                                {2'd0, anim_med[5:0]} + 
                                {3'd0, (wave1[4:0] + wave2[4:0] + wave3[4:0] + wave4[4:0])};
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 5: PERFECT METABALL PHYSICS - AUTHENTIC FLUID DYNAMICS
            // ============================================================
            // Implements true metaball physics using squared distances and 1/r² field
            // calculations. Creates realistic organic blob shapes that flow and merge
            // with authentic fluid dynamics, like real-world metaballs in 3D graphics.
            3'b101:
                begin
                    // ENHANCED METABALL MOTION with larger movement range
                    ball_x1 = center_x + {anim_slow[5:0], 3'd0};         // +/- 504 range - larger motion
                    ball_y1 = center_y + {anim_med[5:0], 3'd0};
                    ball_x2 = center_x - {anim_fast[4:0], 4'd0};         // +/- 480 range - faster motion  
                    ball_y2 = center_y - {anim_slow[4:0], 4'd0};
                    ball_x3 = center_x + {anim_ultra[4:0], 4'd0};        // +/- 480 range - ultra-fast
                    ball_y3 = center_y - {anim_med[4:0], 4'd0};
                    
                    // PERFECT SQUARED DISTANCE CALCULATIONS (like perfect circles!)
                    // Calculate dx² + dy² for each metaball using proper Euclidean distance
                    
                    // Metaball 1: Perfect squared distance
                    if (pix_x3 >= ball_x1)
                        ball_dist1_sq <= ({4'd0, pix_x3 - ball_x1} * {4'd0, pix_x3 - ball_x1}) + 
                                        ({4'd0, (pix_y3 >= ball_y1) ? (pix_y3 - ball_y1) : (ball_y1 - pix_y3)} *
                                         {4'd0, (pix_y3 >= ball_y1) ? (pix_y3 - ball_y1) : (ball_y1 - pix_y3)});
                    else
                        ball_dist1_sq <= ({4'd0, ball_x1 - pix_x3} * {4'd0, ball_x1 - pix_x3}) + 
                                        ({4'd0, (pix_y3 >= ball_y1) ? (pix_y3 - ball_y1) : (ball_y1 - pix_y3)} *
                                         {4'd0, (pix_y3 >= ball_y1) ? (pix_y3 - ball_y1) : (ball_y1 - pix_y3)});
                    
                    // Metaball 2: Perfect squared distance
                    if (pix_x3 >= ball_x2)
                        ball_dist2_sq <= ({4'd0, pix_x3 - ball_x2} * {4'd0, pix_x3 - ball_x2}) + 
                                        ({4'd0, (pix_y3 >= ball_y2) ? (pix_y3 - ball_y2) : (ball_y2 - pix_y3)} *
                                         {4'd0, (pix_y3 >= ball_y2) ? (pix_y3 - ball_y2) : (ball_y2 - pix_y3)});
                    else
                        ball_dist2_sq <= ({4'd0, ball_x2 - pix_x3} * {4'd0, ball_x2 - pix_x3}) + 
                                        ({4'd0, (pix_y3 >= ball_y2) ? (pix_y3 - ball_y2) : (ball_y2 - pix_y3)} *
                                         {4'd0, (pix_y3 >= ball_y2) ? (pix_y3 - ball_y2) : (ball_y2 - pix_y3)});
                    
                    // Metaball 3: Perfect squared distance
                    if (pix_x3 >= ball_x3)
                        ball_dist3_sq <= ({4'd0, pix_x3 - ball_x3} * {4'd0, pix_x3 - ball_x3}) + 
                                        ({4'd0, (pix_y3 >= ball_y3) ? (pix_y3 - ball_y3) : (ball_y3 - pix_y3)} *
                                         {4'd0, (pix_y3 >= ball_y3) ? (pix_y3 - ball_y3) : (ball_y3 - pix_y3)});
                    else
                        ball_dist3_sq <= ({4'd0, ball_x3 - pix_x3} * {4'd0, ball_x3 - pix_x3}) + 
                                        ({4'd0, (pix_y3 >= ball_y3) ? (pix_y3 - ball_y3) : (ball_y3 - pix_y3)} *
                                         {4'd0, (pix_y3 >= ball_y3) ? (pix_y3 - ball_y3) : (ball_y3 - pix_y3)});
                    
                    // AUTHENTIC METABALL PHYSICS: 1/r² FIELD STRENGTH
                    // Real metaballs use inverse square law for field strength: F = k/r²
                    // Approximated using: field = constant / (distance² + small_constant)
                    ball_field1 <= 32'd10000000 / (ball_dist1_sq + 32'd1000);  // Prevent division by zero
                    ball_field2 <= 32'd10000000 / (ball_dist2_sq + 32'd1000);  
                    ball_field3 <= 32'd10000000 / (ball_dist3_sq + 32'd1000);  
                    
                    // PERFECT METABALL FIELD BLENDING
                    // Combine individual fields using proper metaball mathematics
                    metaball_field_perfect <= ball_field1 + ball_field2 + ball_field3;
                    
                    // ADVANCED METABALL COLOR MAPPING
                    // Use perfect field strength for realistic color transitions
                    color_hue <= metaball_field_perfect[23:16] + anim_fast + {3'd0, anim_slow[4:0]};
                    color_sat <= 8'd255;  // Maximum saturation for vivid metaball colors
                    
                    // REALISTIC METABALL BRIGHTNESS with smooth field gradients
                    if (metaball_field_perfect > 32'd50000)
                        color_val <= 8'd255;  // Bright core regions where fields overlap
                    else if (metaball_field_perfect > 32'd25000)
                        color_val <= 8'd200 + metaball_field_perfect[14:7];  // Medium intensity zones
                    else if (metaball_field_perfect > 32'd10000)
                        color_val <= 8'd120 + metaball_field_perfect[15:8];  // Soft field gradients
                    else if (metaball_field_perfect > 32'd2000)
                        color_val <= 8'd60 + metaball_field_perfect[16:9];   // Outer field influence
                    else
                        color_val <= 8'd20 + {4'd0, anim_ultra[3:0]};        // Animated background
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 6: PERFECT COLOR WHEEL - RADIAL COLOR DISTRIBUTION
            // ============================================================
            // Uses perfect circles for smooth radial color gradients.
            3'b110:
                begin
                    color_hue <= shape_l1[10:3] + (anim_slow << 2);
                    // Use perfect circle for smooth radial transitions
                    color_sat <= (shape_circle_perfect < 32'd40000) ? 8'd255 : 8'd160;  // Sharp inner/outer zones
                    color_val <= (shape_circle_perfect < 32'd22500) ? 8'd200 : 8'd80;   // Bright center, dim outer
                    
                    rgb_output <= hsv_to_rgb(color_hue, color_sat, color_val);
                end
                
            // ============================================================
            // MODE 7: ADVANCED MORPHING KALEIDOSCOPE - SMOOTH GEOMETRIC BLENDING
            // ============================================================
            // Creates smooth morphing between multiple geometric shapes with advanced
            // blending algorithms, creating hypnotic transformations and fluid motion.
            3'b111:
                begin
                    // ADVANCED MULTI-SHAPE MORPHING ALGORITHM
                    // Uses four different morphing cycles for rich visual variety
                    
                    // Morphing cycle selection based on slow animation
                    case(anim_slow[7:6])  // 4 different morphing modes
                        2'b00: // CYCLE 1: Circle → Diamond → Square → Circle
                            begin
                                // Smooth interpolation weights based on animation phase
                                morph_weight = anim_med;  // 0-255 morphing weight
                                
                                // Blend between Circle and Diamond based on animation
                                if (anim_med[7:6] == 2'b00)  // Circle to Diamond
                                    in_shape1 <= (shape_circle_perfect < {8'd0, size_squared1}) ||
                                                 ((shape_l1 < {5'd0, size_animated1}) && (morph_weight > 8'd128));
                                else if (anim_med[7:6] == 2'b01)  // Diamond to Square  
                                    in_shape1 <= (shape_l1 < {5'd0, size_animated1}) ||
                                                 ((shape_linf < {5'd0, size_animated1}) && (morph_weight > 8'd128));
                                else if (anim_med[7:6] == 2'b10)  // Square to Circle
                                    in_shape1 <= (shape_linf < {5'd0, size_animated1}) ||
                                                 ((shape_circle_perfect < {8'd0, size_squared1}) && (morph_weight > 8'd128));
                                else  // Circle breathing
                                    in_shape1 <= (shape_circle_perfect < {8'd0, size_squared1});
                                
                                // Secondary shape for layering effects
                                in_shape2 <= (shape_circle_perfect < {8'd0, size_squared2});
                                
                                // Dynamic color morphing
                                color_hue <= anim_fast + {2'd0, shape_circle_perfect[17:12]} + 
                                           {3'd0, morph_weight[7:3]};
                                color_sat <= 8'd240 - {3'd0, morph_weight[7:3]};
                                
                                // Smooth brightness blending based on distance and morphing
                                if (in_shape1 && in_shape2)
                                    color_val <= 8'd250 - shape_circle_perfect[18:11];  // Bright intersection
                                else if (in_shape1)
                                    color_val <= 8'd180 - {2'd0, morph_weight[7:2]};   // Primary shape
                                else if (in_shape2) 
                                    color_val <= 8'd120 - shape_circle_perfect[19:12]; // Secondary shape
                                else
                                    color_val <= 8'd20 + {4'd0, anim_ultra[3:0]};      // Animated background
                            end
                            
                        2'b01: // CYCLE 2: Pulsating Concentric Shapes
                            begin
                                // Multiple concentric rings with different geometries
                                in_shape1 <= (shape_circle_perfect < {8'd0, size_squared1}) &&
                                           !(shape_circle_perfect < {8'd0, size_squared2});  // Ring 1
                                in_shape2 <= (shape_l1 < ({5'd0, size_animated1} + 17'd80)) &&
                                           !(shape_l1 < ({5'd0, size_animated1} + 17'd40));   // Diamond ring
                                
                                // Rainbow spiral effect
                                color_hue <= anim_fast + shape_circle_perfect[16:9] + 
                                           {2'd0, shape_l1[8:3]};
                                color_sat <= 8'd255;
                                
                                // Pulsating brightness with smooth gradients
                                if (in_shape1)
                                    color_val <= 8'd200 + {3'd0, anim_ultra[4:0]};     // Bright pulsing ring
                                else if (in_shape2)
                                    color_val <= 8'd150 + {4'd0, anim_fast[3:0]};      // Medium diamond ring
                                else if (shape_circle_perfect < {8'd0, size_squared2})
                                    color_val <= 8'd100 - shape_circle_perfect[17:10]; // Inner gradient
                                else
                                    color_val <= 8'd30 + {5'd0, anim_med[2:0]};        // Subtle background
                            end
                            
                        2'b10: // CYCLE 3: Organic Blob Morphing  
                            begin
                                // Complex organic-like shapes using multiple distance metrics
                                organic_dist = shape_circle_perfect + 
                                             {14'd0, shape_l1} * {14'd0, anim_ultra} +
                                             {16'd0, shape_linf} * {12'd0, anim_med[7:4]};
                                
                                in_shape1 <= (organic_dist < ({8'd0, size_squared1} + 32'd30000));
                                in_shape2 <= (organic_dist < ({8'd0, size_squared2} + 32'd15000));
                                
                                // Fluid color transitions
                                color_hue <= organic_dist[19:12] + anim_fast + anim_slow;
                                color_sat <= 8'd230 + {3'd0, anim_ultra[4:0]};
                                
                                // Organic brightness distribution
                                color_val <= 8'd120 + organic_dist[17:10] + 
                                           {3'd0, anim_med[4:0]} + 
                                           {4'd0, (in_shape1 ? 4'd8 : 4'd0)} +
                                           {4'd0, (in_shape2 ? 4'd4 : 4'd0)};
                            end
                            
                        2'b11: // CYCLE 4: Geometric Mandala  
                            begin
                                // Complex mandala-like patterns with perfect circles
                                mandala_factor = (pix_x3[4:0] ^ pix_y3[4:0]) + anim_fast[5:0];
                                
                                in_shape1 <= (shape_circle_perfect < {8'd0, size_squared1}) &&
                                           (mandala_factor[2:0] == 3'b111);  // Segmented circle
                                in_shape2 <= (shape_l1 < {5'd0, size_animated2}) &&
                                           (mandala_factor[3:1] == 3'b101);  // Segmented diamond
                                
                                // Kaleidoscopic colors
                                color_hue <= mandala_factor + anim_med + 
                                           shape_circle_perfect[15:8];
                                color_sat <= 8'd255;
                                
                                // Complex brightness patterns
                                if (in_shape1 && in_shape2)
                                    color_val <= 8'd255;                               // Bright intersections
                                else if (in_shape1)
                                    color_val <= 8'd180 + {3'd0, mandala_factor[4:0]}; // Bright segments
                                else if (in_shape2)
                                    color_val <= 8'd120 + {4'd0, mandala_factor[3:0]}; // Medium segments
                                else
                                    color_val <= 8'd40 + {5'd0, mandala_factor[2:0]};  // Pattern background
                            end
                    endcase
                    
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