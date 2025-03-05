# Klic App Improvement Specification

## Overview
Klic is a macOS application designed for Twitch streamers to display keyboard, mouse, and trackpad inputs on screen. This document outlines the current issues and planned improvements to enhance the application's functionality, reliability, and user experience.

## Current Issues

### Input Monitoring Issues
1. ~~**Mouse Movements Displayed as Left Clicks**: Mouse movements are incorrectly shown as left click events.~~ (FIXED)
2. ~~**Trackpad Gestures Not Showing**: Various trackpad gestures are not being properly captured or displayed.~~ (FIXED)
3. ~~**Fast Typing Not Displayed Correctly**: When typing quickly, the keyboard input display doesn't accurately show all keystrokes.~~ (FIXED)

### UI/UX Issues
1. **No Menu Bar for Settings**: The app lacks a menu bar for easy access to settings.
2. **Limited Overlay Positioning**: Users cannot move the overlay position as needed.
3. **No Option for Expanded Notch Area**: There's no capability to display the overlay in the expanded notch area of newer MacBooks.

### Technical Issues
1. ~~**App Structure Error**: The KlicApp was defined as a class instead of a struct, causing crashes.~~ (FIXED)
2. ~~**Input Event Handling**: The current implementation may not be efficiently capturing all input events.~~ (FIXED)

## Planned Improvements

### Phase 1: Core Functionality Fixes
- [x] **Fix App Structure**: Change KlicApp from class to struct to comply with SwiftUI's App protocol.
- [x] **Improve Mouse Input Handling**: Correctly differentiate between mouse movements and clicks.
- [x] **Enhance Trackpad Monitoring**: Implement proper tracking for various trackpad gestures.
- [x] **Optimize Keyboard Input**: Ensure accurate display of fast typing sequences.

### Phase 2: User Interface Enhancements
- [ ] **Add Menu Bar**: Implement a menu bar for quick access to settings and preferences.
- [ ] **Flexible Overlay Positioning**: Allow users to position the overlay anywhere on screen.
- [ ] **Expanded Notch Support**: Add option to display in the expanded notch area of newer MacBooks.
- [ ] **Modern UI Design**: Refresh the interface with a minimal, clean design inspired by apps like Vercel, Linear, and Arc.

### Phase 3: Advanced Features
- [ ] **Custom Visualizations**: Allow users to customize the appearance of input visualizations.
- [ ] **Presets**: Create preset configurations for different streaming scenarios.
- [ ] **Input Filtering**: Option to show only certain types of inputs.
- [ ] **Recording & Playback**: Allow recording of input sessions for later visualization.

## Technical Implementation Details

### Mouse and Trackpad Input Improvements (Completed)
- ✅ Fixed mouse movement handling by properly distinguishing between movement events and clicks
- ✅ Enhanced trackpad gesture detection to recognize more subtle movements
- ✅ Lowered thresholds for pinch, rotation, and swipe detection
- ✅ Improved multi-touch gesture recognition

### Keyboard Input Optimization (Completed)
- ✅ Enhanced key filtering for fast typing sequences
- ✅ Added dynamic typing rate detection
- ✅ Improved handling of special keys and modifiers
- ✅ Fixed key-up event processing to maintain accurate state

### UI/UX Enhancements (Pending)
- Implement a status bar menu using `NSMenu` and `NSStatusItem`
- Create a drag interface for overlay positioning
- Add preferences option for notch area display on supported models

## Timeline
- **Phase 1**: ✅ Completed
- **Phase 2**: 2-3 weeks
- **Phase 3**: 3-4 weeks

## Success Metrics
- ✅ Fixed crashes during extended use
- ✅ Accurate display of all input types
- Positive user feedback on positioning flexibility
- Improved streaming experience for content creators

## Next Steps
1. Begin Phase 2 implementation focusing on UI/UX improvements
2. Add custom positioning functionality to the overlay
3. Enhance the menu bar options for better accessibility
4. Refine the visual design for a more modern appearance 