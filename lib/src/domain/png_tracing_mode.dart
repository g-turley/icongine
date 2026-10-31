/// How PNG alpha is converted into font outlines; SVG geometry is unaffected.
enum PngTracingMode {
  /// Original thresholded boundary tracing and smoothing for older output.
  legacy,

  /// Default: interpolated alpha contours with bounded, corner-aware curves.
  smooth,

  /// Exact pixel boundaries at 50% alpha, without smoothing.
  pixel;

  static PngTracingMode parse(String value) => switch (value
      .trim()
      .toLowerCase()) {
    'legacy' => legacy,
    'smooth' => smooth,
    'pixel' => pixel,
    _ => throw FormatException(
      'Unsupported PNG tracing mode "$value". Use legacy, smooth, or pixel.',
    ),
  };
}
