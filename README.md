# 🌈 Tang Nano 20K Kaleidoscopic Pattern Generator

**Transform your Tang Nano 20K FPGA into a mesmerizing kaleidoscopic pattern generator with real-time HDMI output!**

![Tang Nano 20K](https://img.shields.io/badge/FPGA-Tang%20Nano%2020K-blue)
![Resolution](https://img.shields.io/badge/Resolution-1280x720@60Hz-green)
![Language](https://img.shields.io/badge/Language-Verilog-orange)
![License](https://img.shields.io/badge/License-Open%20Source-brightgreen)

## 📖 Overview

This project generates stunning animated kaleidoscopic patterns directly from the Tang Nano 20K FPGA board and outputs them via HDMI at full 1280x720@60Hz resolution. Watch as mathematical algorithms create hypnotic geometric patterns that cycle through 8 different visual modes with smooth real-time animation.

### ✨ Key Features

- 🎨 **8 High-Quality Pattern Modes**: Enhanced diamonds, true circles, smooth squares, spirals, plasma effects, metaballs, color wheels, and morphing shapes
- 🖥️ **Full HD Output**: 1280x720@60Hz HDMI compatible with any monitor or TV
- ⚡ **Real-time Generation**: All patterns calculated in hardware at 74.25MHz pixel clock
- 🌈 **Vibrant Colors**: Enhanced HSV color space with anti-aliased gradients and smooth transitions
- 🔄 **Auto-cycling**: Patterns automatically change every ~1 second for continuous visual variety
- 💫 **Fluid Animation**: Optimized multi-speed animation system creates organic, smooth motion
- 🎯 **Optimized Design**: 5-stage pipeline architecture ensures stable high-frequency operation
- ✨ **Anti-aliased Graphics**: Smooth gradients eliminate pixelation for professional visual quality

## 🛠️ Hardware Requirements

### Essential Hardware
- **Tang Nano 20K FPGA Board** (Gowin GW2AR-LV18QN88C8/I7)
- **HDMI Cable** (connect to monitor/TV)
- **USB-C Cable** (for programming and power)

### Optional Hardware
- Monitor or TV with HDMI input
- HDMI to DVI adapter (if needed for older displays)

## 🎨 Pattern Modes

The system automatically cycles through 8 mathematical pattern generators:

| Mode | Pattern Type | Description |
|------|-------------|-------------|
| **0** | 💎 **Smooth Animated Diamonds** | L1 norm distance with anti-aliased gradients and vibrant colors |
| **1** | 🔵 **High-Quality Circles** | Improved Euclidean distance for true circular patterns with smooth edges |
| **2** | ⬜ **Smooth Rotating Squares** | L∞ norm with gradient shading for high-quality square patterns |
| **3** | 🌀 **Enhanced Rainbow Spiral** | Multi-frequency spiraling with smooth color transitions |
| **4** | ⚡ **Advanced Plasma Physics** | 4-wave interference with mathematical wave physics and sine approximations |
| **5** | 🫧 **Perfect Metaball Physics** | Authentic 1/r² field calculations with perfect squared distance metaball dynamics |
| **6** | 🎡 **Color Wheel** | Radial color distribution with distance-based saturation |
| **7** | 🔄 **Advanced Morphing Kaleidoscope** | 4 distinct morphing cycles: geometric transitions, concentric rings, organic blobs, and geometric mandalas |

## 🆕 Recent Improvements

### Visual Quality Enhancements
- **🔵 Perfect Circular Patterns**: Mathematically perfect circles using x² + y² = r² (no approximation!)
- **🎨 Anti-aliased Gradients**: Smooth color transitions replace hard edges for professional quality
- **💫 Fluid Animation**: Optimized timing creates organic, natural motion patterns
- **🌈 Enhanced Colors**: Higher saturation and better color distribution for vivid visuals
- **📐 Precision Mathematics**: Better distance calculations for accurate geometric shapes

### Technical Improvements
- **Distance Algorithm**: Revolutionary upgrade from approximation to perfect x² + y² = r² calculation
- **Animation Timing**: Smoother frame-based animations with multi-frequency blending
- **Color Precision**: Higher bit precision for gradients and smoother transitions
- **Size Scaling**: Improved breathing effects with organic size variations
- **Edge Quality**: Soft edges and anti-aliasing eliminate pixelation

### 🎯 Perfect Circle Breakthrough
The latest update implements **mathematically perfect circles** using the true equation of a circle:
```
x² + y² = r²  (Perfect Circle Equation)
```
This replaces all previous approximation methods with exact calculations, delivering:
- ✨ **Zero geometric distortion** - true circular patterns
- 🔬 **32-bit precision** - ultra-smooth gradients 
- 📐 **Exact mathematics** - no octagonal artifacts
- 🎨 **Professional quality** - broadcast-ready visuals

### ⚡ Advanced Plasma & Metaball Physics
**Mode 4 & 5** now implement authentic physics algorithms:

**Plasma Physics Breakthrough:**
- **4-Wave Interference**: Multiple wave frequencies with mathematical interference
- **Sine Approximations**: Parabolic sine/cosine approximations for realistic waves  
- **Cross-Interference**: Wave harmonics and frequency mixing
- **Field Mathematics**: Proper wave physics with constructive/destructive interference

**Metaball Physics Revolution:**
- **Perfect Squared Distance**: x² + y² calculations for each metaball
- **1/r² Field Strength**: Authentic inverse square law physics (F = k/r²)
- **Proper Field Blending**: Mathematical metaball field combination
- **Realistic Dynamics**: True 3D graphics-quality metaball behavior

## 🚀 Quick Start

### 1. Prerequisites
- Install [Gowin EDA](https://www.gowinsemi.com/en/support/home/) software
- Have a Tang Nano 20K board ready
- Connect HDMI cable to your display

### 2. Programming the FPGA
```bash
# Clone or download this project
# Open hdmi.gprj in Gowin EDA
# Synthesize and program to Tang Nano 20K
```

### 3. Enjoy the Show!
- Connect HDMI cable between Tang Nano 20K and your display
- Power on the board
- Watch the kaleidoscopic patterns begin automatically
- The onboard LED will pulse to indicate the system is running

## 📁 Project Structure

```
hdmi/
├── README.md                 # This file
├── hdmi.gprj                 # Gowin EDA project file
├── hdmi.fs                   # FPGA configuration file
├── src/                      # Source code directory
│   ├── video_top.v           # Top-level module (system coordinator)
│   ├── testpattern.v         # Kaleidoscopic pattern generation engine
│   ├── hdmi.cst              # Pin constraint file (Tang Nano 20K pinout)
│   ├── nano_20k_video.sdc    # Timing constraint file
│   ├── dvi_tx/               # HDMI/DVI transmission IP
│   │   └── dvi_tx.v          # TMDS encoder (encrypted Gowin IP)
│   └── gowin_rpll/           # PLL clock generation IP
│       └── TMDS_rPLL.v       # 371.25MHz TMDS clock PLL
├── impl/                     # Implementation files (generated)
│   ├── gwsynthesis/          # Synthesis results
│   └── pnr/                  # Place and route results
```

## 🔧 Technical Specifications

### Video Output
- **Resolution**: 1280×720 pixels (720p)
- **Refresh Rate**: 60Hz
- **Color Depth**: 24-bit RGB (8 bits per channel)
- **Interface**: HDMI 1.4 compatible
- **Pixel Clock**: 74.25MHz
- **TMDS Clock**: 371.25MHz (5× pixel clock)

### Clock Architecture
- **Input Clock**: 27MHz (Tang Nano 20K onboard oscillator)
- **PLL Multiplication**: ~13.75× to generate TMDS clock
- **Clock Domains**: 27MHz system, 371.25MHz TMDS, 74.25MHz pixel

### Pattern Generation
- **Algorithm**: Real-time mathematical pattern synthesis
- **Pipeline**: 5-stage processing pipeline for high-frequency operation
- **Color Space**: HSV→RGB conversion for smooth gradients
- **Animation**: Multi-speed counters for complex temporal effects

## 🧮 Mathematical Foundation

The kaleidoscopic patterns are generated using distance metrics and geometric transformations:

- **L1 Norm (Manhattan Distance)**: `|x| + |y|` creates diamond patterns
- **L2 Norm (Euclidean Distance)**: `√(x² + y²)` creates circular patterns  
- **L∞ Norm (Chebyshev Distance)**: `max(|x|, |y|)` creates square patterns
- **Metaball Fields**: Distance-based field calculations for organic shapes
- **HSV Color Mapping**: Hue rotation with distance-based saturation and value

## 🎛️ Customization

### Modifying Pattern Parameters
Edit `testpattern.v` to customize:
- Animation speeds (lines 318-321)
- Color palettes (HSV values in pattern modes)
- Pattern sizes and scaling factors
- Mode cycling timing

### Adding New Patterns
1. Add new case in the pattern mode switch statement (line 456)
2. Implement your mathematical algorithm using distance metrics
3. Map results to HSV color space
4. Test with hardware or simulation

### Changing Video Resolution
1. Modify timing parameters in `video_top.v` (lines 137-147)
2. Update PLL configuration for new pixel clock requirements
3. Adjust constraint files if needed

## 🔍 Troubleshooting

### No HDMI Output
- Check HDMI cable connection
- Verify monitor supports 1280x720@60Hz
- Ensure FPGA is properly programmed
- Check power supply (LED should pulse)

### Pattern Issues
- Verify PLL lock status (LED indicates system health)
- Check timing constraints in synthesis reports
- Ensure clock domains are properly constrained

### Build Errors
- Use Gowin EDA version 1.9.8 or later
- Verify all IP cores are properly licensed
- Check file paths in project settings

## 📚 Learning Resources

This project demonstrates advanced FPGA concepts:

- **Video Generation**: Complete HDMI implementation from scratch
- **Clock Domain Crossing**: Multiple clock domains with proper synchronization
- **Pipeline Design**: High-frequency processing techniques
- **Mathematical Algorithms**: Real-time computational geometry
- **Color Theory**: HSV color space and gradient generation
- **Hardware Optimization**: FPGA-specific design patterns

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Additional pattern algorithms
- Better color schemes
- Audio visualization integration
- User interface for pattern selection
- Performance optimizations

## 📄 License

This project is open source. The Gowin IP cores (DVI_TX, rPLL) are provided under Gowin's license terms.

## 🙏 Acknowledgments

- **Gowin Semiconductor**: For the Tang Nano 20K platform and development tools
- **FPGA Community**: For sharing knowledge and inspiration
- **Mathematics**: For providing the beautiful geometric foundations

---

**Enjoy your kaleidoscopic journey! 🌈✨**

> *Transform mathematics into visual art with the power of FPGAs*
