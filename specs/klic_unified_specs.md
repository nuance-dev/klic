# Klic - Next-Gen Input Visualizer for macOS

## Overview
Klic is a modern, minimal input visualization app for macOS that displays keyboard shortcuts and mouse movements in a beautiful overlay at the bottom center of the screen. Designed with a next-gen aesthetic inspired by Vercel, Linear, and Apple, Klic provides streamers, presenters, and educators with an elegant way to showcase their inputs.

## Core Features

### 1. Keyboard Visualization
- Real-time display of keyboard inputs with elegant animations
- Special visualization for modifier keys (Command, Option, Shift, Control)
- Combination shortcuts displayed with connecting lines/animations
- Minimal, clean typography for key labels
- Subtle animations for keypress and release

### 2. Mouse Visualization
- Cursor position tracking with elegant trail effect
- Click visualization (left, right, middle buttons)
- Scroll wheel actions displayed as directional indicators
- Mouse movement speed represented through trail intensity

### 3. UI/UX Design Principles
- Floating overlay with fixed position at bottom center
- Adjustable opacity
- Dark mode with subtle accent colors
- Minimal, distraction-free design
- Adaptive sizing based on screen resolution

## Technical Architecture

### Core Components

1. **Input Monitoring System**
   - `KeyboardMonitor`: Captures keyboard events using macOS APIs
   - `MouseMonitor`: Monitors cursor position, clicks, and scroll actions

2. **Visualization Layer**
   - `KeyboardVisualizer`: Renders keyboard inputs with animations
   - `MouseVisualizer`: Shows cursor movements and actions
   - `InputOverlayView`: Manages the overall overlay appearance

3. **Settings & Configuration**
   - User preferences for opacity and appearance
   - Control over which input types to display

### Technical Requirements

1. **System Access**
   - Accessibility permissions for input monitoring
   - Screen recording permissions for overlay positioning

2. **Performance Considerations**
   - Low CPU/GPU usage to minimize impact on other applications
   - Efficient rendering using Metal/SwiftUI
   - Minimal memory footprint

3. **Compatibility**
   - macOS 12.0+ (Monterey and newer)
   - Support for Apple Silicon and Intel processors

## Design Language

- **Typography**: SF Pro Display, clean and minimal
- **Color Palette**: Dark background (#121212) with accent colors
- **Animations**: Subtle, fluid transitions with spring physics
- **Shapes**: Rounded rectangles with subtle shadows
- **Spacing**: Generous whitespace, golden ratio proportions

## Completed Improvements

### 1. Fixed Input Visualization
- **Improved brief overlay display**: The overlay now appears briefly and automatically fades away after input is detected.
- **Smart timing for auto-hide**: Each input type now has its own timer to cleanly fade out (1.5 seconds) after no new inputs are detected.
- **Limited visible inputs**: Reduced the number of simultaneously visible keyboard events (6) and mouse events (3) to prevent visual clutter.
- **Fixed menu bar "Show Overlay" functionality**: Added demo mode with proper examples of keyboard shortcuts and mouse clicks.

### 2. Next-Gen Design and UI
- **Modern glass effect**: Implemented a premium dark glass material with subtle inner glow and refined gradients.
- **Dynamic containers**: Containers now only appear when relevant inputs are detected rather than showing all container types at once.
- **Improved visualization aesthetics**: Added subtle shadows and refined the overall look with inspiration from Vercel, Linear, and Arc.
- **Removed info/settings button**: Settings are now only accessible from the menu bar for cleaner visualization.
- **Completely hidden window controls**: Fixed window control visibility by properly hiding title bar and window controls.

### 3. Fixed Keyboard Shortcut Display
- **Improved modifier key handling**: Fixed combination display for keys like Cmd+Shift+R.
- **Enhanced key capsule design**: Updated with a modern look and subtle animations.
- **Proper key event clearing**: Keys now disappear after a brief period rather than staying visible indefinitely.
- **Smart key grouping**: Related key inputs are now grouped together for better visual clarity.

### 4. Technical Improvements
- **Optimized event processing**: Improved filtering of rapid input events to prevent visual clutter.
- **Better event timing**: Added precise timing for event display and removal.
- **Fixed permission handling**: Better detection and handling of accessibility permissions.
- **Improved window management**: Fixed issues with window appearance and controls.

## Next Steps for Future Development
1. **Additional style themes**: Add customizable themes for different streaming environments
2. **Enhanced keyboard shortcut display**: Add special visualization for application-specific shortcuts
3. **Performance optimizations**: Further optimize CPU/GPU usage for prolonged streaming sessions
4. **Haptic feedback integration**: Add optional haptic feedback for key input detection 