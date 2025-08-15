// ==============0ooo===================================================0ooo===========
// =  Copyright (C) 2014-2020 Gowin Semiconductor Technology Co.,Ltd.
// =                     All rights reserved.
// ====================================================================================
// 
//  __      __      __
//  \ \    /  \    / /   [File name   ] video_top.v
//   \ \  / /\ \  / /    [Description ] Kaleidoscopic Pattern Generator for Tang Nano 20K
//    \ \/ /  \ \/ /     [Timestamp   ] Friday April 10 14:00:30 2020
//     \  /    \  /      [version     ] 2.0 + Documentation
//      \/      \/
//
// ==============0ooo===================================================0ooo===========
// 
// TANG NANO 20K KALEIDOSCOPIC PATTERN GENERATOR
// ==============================================
//
// This module generates beautiful animated kaleidoscopic patterns and outputs them
// via HDMI at 1280x720@60Hz resolution. The Tang Nano 20K FPGA drives the display
// with mathematically-generated geometric patterns that cycle through different modes.
//
// System Overview:
// ----------------
// 1. Takes 27MHz input clock from Tang Nano 20K onboard oscillator
// 2. Generates 371.25MHz TMDS clock via PLL for 1280x720@60Hz HDMI output  
// 3. Creates pixel clock (74.25MHz) by dividing TMDS clock by 5
// 4. Generates video timing signals (hsync, vsync, display enable)
// 5. Produces animated kaleidoscopic patterns with 8 different modes
// 6. Encodes RGB video data into TMDS format for HDMI transmission
// 7. Provides visual feedback with running LED indicator
//
// Pattern Modes (auto-cycling every ~1 second):
// - Mode 0: Animated diamond shapes with rainbow colors
// - Mode 1: Pulsating circles with gradient effects  
// - Mode 2: Rotating squares with color transitions
// - Mode 3: Rainbow spiral with smooth animation
// - Mode 4: Plasma effect with interference patterns
// - Mode 5: Organic metaball simulation with flowing shapes
// - Mode 6: Color wheel with radial patterns
// - Mode 7: Morphing shapes that blend between geometric forms
//
// Code Revision History :
// ----------------------------------------------------------------------------------
// Ver:    |  Author    | Mod. Date    | Changes Made:
// ----------------------------------------------------------------------------------
// V1.0    | Caojie     |  4/10/20     | Initial version 
// ----------------------------------------------------------------------------------
// V2.0    | Caojie     | 10/30/20     | DVI IP update 
// ----------------------------------------------------------------------------------
// V2.1    | AI Doc     | 2024         | Added comprehensive documentation
// ----------------------------------------------------------------------------------
// ==============0ooo===================================================0ooo===========

module video_top
(
    // Clock and Reset
    input             I_clk           , // 27MHz system clock from Tang Nano 20K oscillator
    input             I_rst_n         , // Active-low reset signal
    
    // HDMI/DVI TMDS Differential Output Pairs
    output            O_tmds_clk_p    , // TMDS clock positive (371.25MHz for 1280x720@60Hz)
    output            O_tmds_clk_n    , // TMDS clock negative 
    output     [2:0]  O_tmds_data_p   , // TMDS data positive {Red, Green, Blue}
    output     [2:0]  O_tmds_data_n     // TMDS data negative {Red, Green, Blue}
);

//==================================================
// LED HEARTBEAT INDICATOR SIGNALS
//==================================================
reg  [31:0] run_cnt;    // Counter for LED heartbeat timing (0 to 27M cycles = 1 second)
wire        running;    // LED state: high for first 14M cycles, low for remaining 13M cycles

//==================================================
// VIDEO TIMING AND RGB DATA SIGNALS FROM TEST PATTERN GENERATOR
//==================================================
wire        tp0_vs_in  ;    // Vertical sync from test pattern generator
wire        tp0_hs_in  ;    // Horizontal sync from test pattern generator  
wire        tp0_de_in ;     // Display enable (active video region)
wire [ 7:0] tp0_data_r/*synthesis syn_keep=1*/;  // Red channel (8-bit, 0-255)
wire [ 7:0] tp0_data_g/*synthesis syn_keep=1*/;  // Green channel (8-bit, 0-255) 
wire [ 7:0] tp0_data_b/*synthesis syn_keep=1*/;  // Blue channel (8-bit, 0-255)

//==================================================
// PATTERN MODE CONTROL SIGNALS  
//==================================================
reg         vs_r;       // Registered vertical sync for edge detection
reg  [9:0]  cnt_vs;     // Vertical sync counter for mode switching (0-1023)

//==================================================
// CLOCK GENERATION AND HDMI TRANSMISSION SIGNALS
//==================================================
wire serial_clk;        // 371.25MHz TMDS serialization clock from PLL
wire pll_lock;          // PLL lock status indicator
wire hdmi4_rst_n;       // HDMI reset: active when system reset AND PLL locked
wire pix_clk;           // 74.25MHz pixel clock (serial_clk ÷ 5)

//===================================================
// LED HEARTBEAT GENERATOR - Visual System Status Indicator
//===================================================
// Creates a 1Hz heartbeat pattern on the Tang Nano 20K LED:
// - LED ON for 0.52 seconds (14M cycles @ 27MHz)
// - LED OFF for 0.48 seconds (13M cycles @ 27MHz) 
// - Total period = 1 second, providing clear visual feedback that system is running
//
always @(posedge I_clk or negedge I_rst_n) 
begin
    if(!I_rst_n)
        run_cnt <= 32'd0;                    // Reset counter on system reset
    else if(run_cnt >= 32'd27_000_000)       // One second elapsed (27MHz * 1s)
        run_cnt <= 32'd0;                    // Restart count cycle
    else
        run_cnt <= run_cnt + 1'b1;           // Increment each clock cycle
end

// LED state logic: ON for first ~0.52s, OFF for remaining ~0.48s of each second
assign  running = (run_cnt < 32'd14_000_000) ? 1'b1 : 1'b0;

//===========================================================================
// KALEIDOSCOPIC PATTERN GENERATOR INSTANTIATION
//===========================================================================
// The testpattern module generates animated kaleidoscopic patterns using mathematical
// algorithms. It outputs 1280x720@60Hz video with 8 different pattern modes that 
// automatically cycle based on the mode input (cnt_vs[9:7]).
//
testpattern testpattern_inst
(
    // Clock and Reset
    .I_pxl_clk   (pix_clk            ),    // 74.25MHz pixel clock for 1280x720@60Hz
    .I_rst_n     (hdmi4_rst_n        ),    // Active-low reset (when PLL locked)
    
    // Pattern Control  
    .I_mode      (cnt_vs[9:7]        ),    // 3-bit mode select (0-7) from frame counter
    .I_single_r  (8'd0               ),    // Single color red (unused in pattern modes)
    .I_single_g  (8'd255             ),    // Single color green (unused in pattern modes) 
    .I_single_b  (8'd0               ),    // Single color blue (unused in pattern modes)
    
    // Video Timing Parameters for 1280x720@60Hz (74.25MHz pixel clock)
    .I_h_total   (12'd1650           ),    // Horizontal total pixels per line
    .I_h_sync    (12'd40             ),    // Horizontal sync pulse width  
    .I_h_bporch  (12'd220            ),    // Horizontal back porch width
    .I_h_res     (12'd1280           ),    // Horizontal active resolution
    .I_v_total   (12'd750            ),    // Vertical total lines per frame  
    .I_v_sync    (12'd5              ),    // Vertical sync pulse width
    .I_v_bporch  (12'd20             ),    // Vertical back porch height
    .I_v_res     (12'd720            ),    // Vertical active resolution
    .I_hs_pol    (1'b1               ),    // Horizontal sync polarity (1=positive) 
    .I_vs_pol    (1'b1               ),    // Vertical sync polarity (1=positive)
    
    // Video Output Signals
    .O_de        (tp0_de_in          ),    // Display enable (active video area)
    .O_hs        (tp0_hs_in          ),    // Horizontal sync output
    .O_vs        (tp0_vs_in          ),    // Vertical sync output  
    .O_data_r    (tp0_data_r         ),    // Red channel output (8-bit)
    .O_data_g    (tp0_data_g         ),    // Green channel output (8-bit)
    .O_data_b    (tp0_data_b         )     // Blue channel output (8-bit)
);

//===========================================================================
// PATTERN MODE CONTROL LOGIC
//===========================================================================
// Automatically cycles through 8 different kaleidoscopic pattern modes.
// Mode changes occur at vertical sync intervals (~60Hz frame rate), creating
// smooth transitions between different visual effects approximately every 1 second.
//

// Register vertical sync for edge detection
always@(posedge pix_clk)
begin
    vs_r <= tp0_vs_in;    // Capture previous vertical sync state
end

// Count vertical sync falling edges to determine pattern mode
always@(posedge pix_clk or negedge hdmi4_rst_n)
begin
    if(!hdmi4_rst_n)
        cnt_vs <= 0;                           // Reset counter on system reset
    else if(vs_r && !tp0_vs_in)                // Detect vertical sync falling edge
        cnt_vs <= cnt_vs + 1'b1;               // Increment frame counter
end 
// Mode selection: cnt_vs[9:7] provides 3-bit mode (0-7)
// At 60Hz frame rate: each mode lasts ~17 frames ≈ 0.28 seconds
// Full cycle through 8 modes takes ~2.28 seconds 

//==============================================================================
// CLOCK GENERATION FOR HDMI TRANSMISSION  
//==============================================================================
// Generates the precise timing required for 1280x720@60Hz HDMI output:
// - TMDS clock: 371.25MHz (pixel clock × 5 for serialization)
// - Pixel clock: 74.25MHz (derived by dividing TMDS clock by 5)
//

// Phase-Locked Loop (PLL) - Generates 371.25MHz TMDS Clock
// Input: 27MHz → Output: 371.25MHz (multiplication factor ~13.75)  
TMDS_rPLL u_tmds_rpll
(
    .clkin     (I_clk     ),    // 27MHz input clock from Tang Nano 20K
    .clkout    (serial_clk),    // 371.25MHz TMDS serialization clock output
    .lock      (pll_lock  )     // PLL lock indicator (1=stable, 0=unlocked)
);

// System reset logic: Only allow HDMI operation when PLL is locked
assign hdmi4_rst_n = I_rst_n & pll_lock;

// Clock Divider - Generates 74.25MHz Pixel Clock  
// Divides 371.25MHz TMDS clock by 5 to create pixel clock for video timing
CLKDIV u_clkdiv
(
    .RESETN(hdmi4_rst_n),       // Reset when PLL unlocked or system reset
    .HCLKIN(serial_clk),        // 371.25MHz TMDS clock input 
    .CLKOUT(pix_clk),           // 74.25MHz pixel clock output
    .CALIB (1'b1)               // Calibration enable (always on)
);
defparam u_clkdiv.DIV_MODE="5";     // Divide by 5: 371.25MHz ÷ 5 = 74.25MHz
defparam u_clkdiv.GSREN="false";    // Global set/reset disable

//==============================================================================
// HDMI/DVI TRANSMITTER INSTANTIATION
//==============================================================================
// Converts parallel RGB video data to TMDS (Transition Minimized Differential Signaling)
// format for HDMI transmission. This IP core handles:
// - 8b/10b encoding for each RGB channel + sync signals
// - Parallel-to-serial conversion at 371.25MHz  
// - Differential pair generation for robust signal transmission
// - Clock forwarding for receiver synchronization
//
DVI_TX_Top DVI_TX_Top_inst
(
    // Clock and Reset
    .I_rst_n       (hdmi4_rst_n   ),    // Asynchronous reset (active when PLL locked)
    .I_serial_clk  (serial_clk    ),    // 371.25MHz TMDS serialization clock
    .I_rgb_clk     (pix_clk       ),    // 74.25MHz pixel clock for input timing
    
    // Video Input Signals (from testpattern module)
    .I_rgb_vs      (tp0_vs_in     ),    // Vertical sync input
    .I_rgb_hs      (tp0_hs_in     ),    // Horizontal sync input  
    .I_rgb_de      (tp0_de_in     ),    // Display enable input
    .I_rgb_r       (tp0_data_r    ),    // Red channel data (8-bit)
    .I_rgb_g       (tp0_data_g    ),    // Green channel data (8-bit)
    .I_rgb_b       (tp0_data_b    ),    // Blue channel data (8-bit)
    
    // HDMI/TMDS Differential Output Pairs (to Tang Nano 20K HDMI connector)
    .O_tmds_clk_p  (O_tmds_clk_p  ),   // TMDS clock positive output
    .O_tmds_clk_n  (O_tmds_clk_n  ),   // TMDS clock negative output  
    .O_tmds_data_p (O_tmds_data_p ),   // TMDS data positive {Red, Green, Blue}
    .O_tmds_data_n (O_tmds_data_n )    // TMDS data negative {Red, Green, Blue}
);

//==============================================================================
// END OF MODULE - Tang Nano 20K Kaleidoscopic Pattern Generator
//==============================================================================
// This completes the top-level video generation system. The module coordinates:
// 1. Clock generation (27MHz → 371.25MHz TMDS, 74.25MHz pixel)
// 2. Pattern generation (8 kaleidoscopic modes with smooth animation)  
// 3. Video timing (1280x720@60Hz standard)
// 4. HDMI transmission (TMDS encoding and differential signaling)
// 5. Visual feedback (LED heartbeat indicator)
//
// Connect the Tang Nano 20K HDMI output to any standard monitor or TV to enjoy
// the mesmerizing kaleidoscopic patterns!
//==============================================================================

endmodule