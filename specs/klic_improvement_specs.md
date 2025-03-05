# Klic - Keystroke Visualizer Improvement Specifications

## Current Issues
1. **No event capturing**: The app doesn't display key inputs, trackpad touches, or mouse movements properly
2. **Always visible overlay**: Two large rectangles are showing at all times instead of appearing briefly when input is detected
3. **Settings in overlay**: Info/settings button in the display overlay doesn't make sense
4. **UI/UX not "next-gen" enough**: The design needs to be more modern, minimal and fluid
5. **Multiple overlays**: Currently shows separate overlays for different input types instead of a unified, elegant view
6. **Window controls visible**: Window controls (close, minimize, expand) are visible in the overlay
7. **Poor trackpad visualization**: Trackpad inputs don't appear correctly, and scrolling shows an arrow in the middle of the screen
8. **Menu bar "Show Overlay" option doesn't work**: The option to show overlay from the menu doesn't function

## Improvement Plan

### 1. Fix Input Monitoring and Event Processing
- Ensure proper permissions are requested and handled
- Fix event taps for keyboard, mouse, and trackpad monitoring
- Implement proper event filtering and processing
- Debug input capture pipeline
- Add graceful fallback when permissions aren't granted

### 2. Implement Smart, Brief Overlay Behavior
- Make overlay show *only* when input is detected and hide automatically after brief period (1.5-2 seconds)
- Create separate overlay components for each input type that appear independently
- Implement smooth fade in/out animations with spring physics
- Ensure overlays appear and disappear subtly without disrupting workflow
- Add grouping for rapid inputs to avoid visual clutter

### 3. Create a Unified, Next-Gen Visual Design
- Implement a unified, minimal container that shows only relevant input information
- Use a clean, modern glass effect with subtle gradients and minimal borders
- Apply elegant typography and iconography similar to Vercel, Linear, Arc
- Remove the info/settings button from the overlay completely
- Make sure window controls are completely hidden
- Create a design that feels "magical" and satisfying to watch

### 4. Improve Trackpad Visualization
- Completely redesign trackpad visualization to show:
  - Single taps with subtle pulse animation
  - Multi-finger taps with finger count indicator
  - Swipes with directional animation
  - Pinch/zoom with elegant scaling animation
  - Rotation with fluid rotation indicators
- Remove the static trackpad rectangle and only show visualizations when trackpad is used
- Add subtle motion trails for more "premium" feel

### 5. Enhance Keyboard Visualization
- Limit visible keyboard inputs to prevent cluttering (max 5-6 keys)
- Group modifier keys with regular keys in a more elegant way
- Add subtle animations for key press and release
- Implement intelligent filtering for rapid typing

### 6. Fix Menu Bar Functionality
- Move all settings to the menu bar
- Fix the "Show Overlay" option
- Ensure proper activation of overlay from menu commands
- Add keyboard shortcuts for common actions

### 7. Technical Implementation Details
- Use SwiftUI animations and transitions with spring physics for fluid motion
- Implement efficient event processing to avoid performance issues
- Ensure accessibility compliance
- Add proper error handling and logging
- Implement background mode to keep monitoring running when needed

### 8. Streamer-Focused Features
- Add option to highlight keyboard shortcuts (like Cmd+C) with special styling
- Implement subtle animations that draw attention without being distracting
- Create a design that looks amazing on streams but doesn't distract viewers
- Add configurable themes that match popular streaming aesthetics

## Implementation Priorities
1. Fix the core input monitoring issues
2. Implement the auto-show/hide behavior
3. Redesign the visual appearance to be truly next-gen
4. Improve the trackpad visualization
5. Fix the menu bar functionality
6. Add streamer-focused enhancements

## Recent Fixes

### March 4, 2025
1. **Fixed access control issues**:
   - Updated `InputOverlayView.swift` to use `.hudWindow` instead of the deprecated `.dark` material for the blur effect
   - Fixed access control issues in `KlicApp.swift` by properly using the public `hideOverlay()` method from `InputManager`
   - Ensured proper encapsulation of private properties in `InputManager` while providing public methods for necessary functionality
   - Successfully built and ran the app with no errors or warnings 