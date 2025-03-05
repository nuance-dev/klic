# Klic Next-Gen Improvements Specification

## Overview
Klic is a macOS app for Twitch streamers that displays keyboard, mouse, and trackpad inputs in a clean, minimal overlay. This document outlines the improvements needed to fix current issues and add new features to make it a next-gen tool for streamers.

## Current Issues to Fix

1. **Mouse Movement Detection**
   - Problem: Mouse movements are incorrectly displayed as left clicks
   - Solution: Fix the mouse event handling in `MouseMonitor.swift` to properly differentiate between movement and click events

2. **Trackpad Gesture Support**
   - Problem: Doesn't display trackpad scrolls, swipes, right clicks, and multi-finger touches
   - Solution: Enhance the `TrackpadMonitor.swift` to properly capture and visualize these events

3. **Keyboard Input Accuracy**
   - Problem: Fast typing breaks the display (e.g., "better" shows as "bebet")
   - Solution: Improve the keyboard event filtering and sequencing in `KeyboardMonitor.swift` and `InputManager.swift`

## New Features to Add

1. **Enhanced Menu Bar**
   - Add comprehensive settings to the menu bar
   - Include position control, opacity settings, and input type toggles

2. **Movable Overlay**
   - Implement drag functionality to reposition the overlay
   - Save position preferences between sessions

3. **Expanded Notch Display**
   - Add option to display in an expanded notch area on new MacBooks
   - Create a specialized UI mode for this display option

## Technical Implementation Plan

### 1. Fix Mouse Movement Detection
- Update `MouseMonitor.swift` to properly differentiate between movement and click events
- Enhance the `MouseVisualizer.swift` to display movements with appropriate animations
- Add proper debouncing for mouse movements to prevent event flooding

### 2. Enhance Trackpad Support
- Update `TrackpadMonitor.swift` to capture all trackpad gestures:
  - Multi-finger swipes
  - Pinch/zoom gestures
  - Rotation gestures
  - Right-click (two-finger tap)
  - Scrolling (two-finger scroll)
- Improve the `TrackpadVisualizer.swift` to show these gestures with intuitive animations
- Add support for displaying raw touch data with accurate finger positions

### 3. Fix Keyboard Input Accuracy
- Improve the event filtering in `InputManager.swift` to handle fast typing
- Add smarter buffering of keyboard events to maintain sequence integrity
- Implement a more robust repeat key detection system

### 4. Enhance Menu Bar and Settings
- Expand the existing menu bar with more comprehensive settings
- Add position control options
- Include input type toggles (keyboard, mouse, trackpad)
- Add theme and appearance settings

### 5. Implement Movable Overlay
- Add drag handle or gesture recognition for moving the overlay
- Save position preferences in UserDefaults
- Ensure the overlay stays within screen bounds

### 6. Create Expanded Notch Display
- Detect MacBooks with notch
- Implement specialized UI for displaying in the notch area
- Create a minimal mode specifically designed for the notch

## Testing Plan
- Test on various macOS versions (Ventura, Sonoma)
- Test on different MacBook models (with and without notch)
- Test with various input devices (Magic Trackpad, Magic Mouse, external keyboards)
- Test during actual streaming sessions to ensure performance

## Success Criteria
- All input types (keyboard, mouse, trackpad) are accurately displayed
- Fast typing is correctly captured and displayed
- Trackpad gestures are intuitively visualized
- The overlay can be easily repositioned
- Settings are accessible and intuitive
- The app performs well during streaming without impacting system performance

## Timeline
1. Fix core input detection issues (mouse, trackpad, keyboard)
2. Implement enhanced visualizations
3. Add movable overlay functionality
4. Implement expanded notch display
5. Enhance menu bar and settings
6. Final testing and refinement 