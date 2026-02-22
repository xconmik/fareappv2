enum MotionPreset {
  soft,
  robotaxi,
  snappy,
}

class MotionProfile {
  final Duration sheet;
  final Duration sheetCollapse;
  final Duration panelSlide;
  final Duration panelFade;
  final Duration bookingSlide;
  final Duration bookingFade;
  final Duration overlaySlide;
  final Duration overlayFade;
  final Duration switcher;
  final Duration chipMorph;
  final Duration chipScale;
  final Duration chipFade;

  const MotionProfile({
    required this.sheet,
    required this.sheetCollapse,
    required this.panelSlide,
    required this.panelFade,
    required this.bookingSlide,
    required this.bookingFade,
    required this.overlaySlide,
    required this.overlayFade,
    required this.switcher,
    required this.chipMorph,
    required this.chipScale,
    required this.chipFade,
  });
}

class MotionPresets {
  static const MotionProfile soft = MotionProfile(
    sheet: Duration(milliseconds: 360),
    sheetCollapse: Duration(milliseconds: 220),
    panelSlide: Duration(milliseconds: 340),
    panelFade: Duration(milliseconds: 260),
    bookingSlide: Duration(milliseconds: 360),
    bookingFade: Duration(milliseconds: 260),
    overlaySlide: Duration(milliseconds: 360),
    overlayFade: Duration(milliseconds: 260),
    switcher: Duration(milliseconds: 420),
    chipMorph: Duration(milliseconds: 340),
    chipScale: Duration(milliseconds: 280),
    chipFade: Duration(milliseconds: 240),
  );

  static const MotionProfile robotaxi = MotionProfile(
    sheet: Duration(milliseconds: 280),
    sheetCollapse: Duration(milliseconds: 170),
    panelSlide: Duration(milliseconds: 280),
    panelFade: Duration(milliseconds: 210),
    bookingSlide: Duration(milliseconds: 300),
    bookingFade: Duration(milliseconds: 220),
    overlaySlide: Duration(milliseconds: 300),
    overlayFade: Duration(milliseconds: 220),
    switcher: Duration(milliseconds: 360),
    chipMorph: Duration(milliseconds: 280),
    chipScale: Duration(milliseconds: 240),
    chipFade: Duration(milliseconds: 210),
  );

  static const MotionProfile snappy = MotionProfile(
    sheet: Duration(milliseconds: 220),
    sheetCollapse: Duration(milliseconds: 130),
    panelSlide: Duration(milliseconds: 220),
    panelFade: Duration(milliseconds: 170),
    bookingSlide: Duration(milliseconds: 240),
    bookingFade: Duration(milliseconds: 180),
    overlaySlide: Duration(milliseconds: 240),
    overlayFade: Duration(milliseconds: 180),
    switcher: Duration(milliseconds: 280),
    chipMorph: Duration(milliseconds: 220),
    chipScale: Duration(milliseconds: 200),
    chipFade: Duration(milliseconds: 170),
  );
}

const MotionProfile kAppMotion = kMotion500Animation300Transition;

// Split timing profile: 500ms for movement/shape animations, 300ms for transitions/fades.
const MotionProfile kMotion500Animation300Transition = MotionProfile(
  sheet: Duration(milliseconds: 500),
  sheetCollapse: Duration(milliseconds: 300),
  panelSlide: Duration(milliseconds: 500),
  panelFade: Duration(milliseconds: 300),
  bookingSlide: Duration(milliseconds: 500),
  bookingFade: Duration(milliseconds: 300),
  overlaySlide: Duration(milliseconds: 500),
  overlayFade: Duration(milliseconds: 300),
  switcher: Duration(milliseconds: 500),
  chipMorph: Duration(milliseconds: 500),
  chipScale: Duration(milliseconds: 500),
  chipFade: Duration(milliseconds: 300),
);
