import '../contour/contour.dart';

/// Parses an SVG path `d` attribute string into a structured [SvgContourPath].
///
/// Implements the Interpreter pattern: each SVG path command letter is a token
/// whose arguments are interpreted into [SvgContourSegment] objects. The parser
/// tracks cursor position to resolve relative commands into absolute coordinates.
///
/// Supported commands (minimum for circle shapes):
///   M/m — moveto (starts a new contour)
///   L/l — lineto
///   H/h — horizontal lineto
///   V/v — vertical lineto
///   C/c — cubic bezier
///   Q/q — quadratic bezier
///   A/a — elliptical arc
///   Z/z — closepath
class SvgPathDataParser {
  const SvgPathDataParser();

  static final RegExp _tokenPattern = RegExp(
    r'[MmLlHhVvCcQqSsTtAaZz]|[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?',
  );

  /// Parses [pathData] into a [SvgContourPath] containing one or more
  /// [SvgContour] sub-paths.
  SvgContourPath parse(String pathData) {
    final tokens = _tokenize(pathData);
    final interpreter = _PathInterpreter(tokens);
    return interpreter.interpret();
  }

  List<String> _tokenize(String pathData) {
    return _tokenPattern
        .allMatches(pathData)
        .map((match) => match.group(0)!)
        .toList(growable: false);
  }
}

/// Internal state machine that walks the token stream and builds contours.
class _PathInterpreter {
  _PathInterpreter(this._tokens);

  final List<String> _tokens;
  int _position = 0;

  double _cursorX = 0;
  double _cursorY = 0;
  double _contourStartX = 0;
  double _contourStartY = 0;
  SvgPoint? _lastCubicControl;
  SvgPoint? _lastQuadraticControl;
  _PathCommandType? _lastCommandType;

  final List<SvgContour> _contours = [];
  List<SvgContourSegment> _currentSegments = [];

  SvgContourPath interpret() {
    while (_position < _tokens.length) {
      final token = _tokens[_position];
      _position += 1;

      switch (token) {
        case 'M':
          _handleMoveTo(isRelative: false);
        case 'm':
          _handleMoveTo(isRelative: true);
        case 'L':
          _handleLineTo(isRelative: false);
        case 'l':
          _handleLineTo(isRelative: true);
        case 'H':
          _handleHorizontalLineTo(isRelative: false);
        case 'h':
          _handleHorizontalLineTo(isRelative: true);
        case 'V':
          _handleVerticalLineTo(isRelative: false);
        case 'v':
          _handleVerticalLineTo(isRelative: true);
        case 'C':
          _handleCubic(isRelative: false);
        case 'c':
          _handleCubic(isRelative: true);
        case 'Q':
          _handleQuadratic(isRelative: false);
        case 'q':
          _handleQuadratic(isRelative: true);
        case 'S':
          _handleSmoothCubic(isRelative: false);
        case 's':
          _handleSmoothCubic(isRelative: true);
        case 'T':
          _handleSmoothQuadratic(isRelative: false);
        case 't':
          _handleSmoothQuadratic(isRelative: true);
        case 'A':
          _handleArc(isRelative: false);
        case 'a':
          _handleArc(isRelative: true);
        case 'Z' || 'z':
          _handleClose();
      }
    }

    _finalizeOpenContour();
    return SvgContourPath(contours: List.unmodifiable(_contours));
  }

  // -- Command handlers --

  void _handleMoveTo({required bool isRelative}) {
    _finalizeOpenContour();

    final targetX = _nextNumber() + (isRelative ? _cursorX : 0);
    final targetY = _nextNumber() + (isRelative ? _cursorY : 0);

    _cursorX = targetX;
    _cursorY = targetY;
    _contourStartX = targetX;
    _contourStartY = targetY;
    _currentSegments = [];
    _clearPreviousControls();
    _lastCommandType = _PathCommandType.move;

    // Implicit lineto commands after the initial moveto coordinate pair.
    while (_hasNumberNext()) {
      _handleLineTo(isRelative: isRelative);
    }
  }

  void _handleLineTo({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final endX = _nextNumber() + (isRelative ? _cursorX : 0);
      final endY = _nextNumber() + (isRelative ? _cursorY : 0);

      _currentSegments.add(
        SvgContourSegment.line(
          start: SvgPoint(startX, startY),
          end: SvgPoint(endX, endY),
        ),
      );

      _cursorX = endX;
      _cursorY = endY;
      _clearPreviousControls();
      _lastCommandType = _PathCommandType.line;
    }
  }

  void _handleHorizontalLineTo({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final endX = _nextNumber() + (isRelative ? _cursorX : 0);

      _currentSegments.add(
        SvgContourSegment.line(
          start: SvgPoint(startX, startY),
          end: SvgPoint(endX, startY),
        ),
      );

      _cursorX = endX;
      _clearPreviousControls();
      _lastCommandType = _PathCommandType.line;
    }
  }

  void _handleVerticalLineTo({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final endY = _nextNumber() + (isRelative ? _cursorY : 0);

      _currentSegments.add(
        SvgContourSegment.line(
          start: SvgPoint(startX, startY),
          end: SvgPoint(startX, endY),
        ),
      );

      _cursorY = endY;
      _clearPreviousControls();
      _lastCommandType = _PathCommandType.line;
    }
  }

  void _handleCubic({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final offsetX = isRelative ? _cursorX : 0;
      final offsetY = isRelative ? _cursorY : 0;

      final control1X = _nextNumber() + offsetX;
      final control1Y = _nextNumber() + offsetY;
      final control2X = _nextNumber() + offsetX;
      final control2Y = _nextNumber() + offsetY;
      final endX = _nextNumber() + offsetX;
      final endY = _nextNumber() + offsetY;

      _currentSegments.add(
        SvgContourSegment.cubic(
          start: SvgPoint(startX, startY),
          control1: SvgPoint(control1X, control1Y),
          control2: SvgPoint(control2X, control2Y),
          end: SvgPoint(endX, endY),
        ),
      );

      _cursorX = endX;
      _cursorY = endY;
      _lastCubicControl = SvgPoint(control2X, control2Y);
      _lastQuadraticControl = null;
      _lastCommandType = _PathCommandType.cubic;
    }
  }

  void _handleQuadratic({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final offsetX = isRelative ? _cursorX : 0;
      final offsetY = isRelative ? _cursorY : 0;

      final control1X = _nextNumber() + offsetX;
      final control1Y = _nextNumber() + offsetY;
      final endX = _nextNumber() + offsetX;
      final endY = _nextNumber() + offsetY;

      _currentSegments.add(
        SvgContourSegment.quadratic(
          start: SvgPoint(startX, startY),
          control1: SvgPoint(control1X, control1Y),
          end: SvgPoint(endX, endY),
        ),
      );

      _cursorX = endX;
      _cursorY = endY;
      _lastQuadraticControl = SvgPoint(control1X, control1Y);
      _lastCubicControl = null;
      _lastCommandType = _PathCommandType.quadratic;
    }
  }

  void _handleSmoothCubic({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final offsetX = isRelative ? _cursorX : 0;
      final offsetY = isRelative ? _cursorY : 0;

      final control1 = _reflectedCubicControl();
      final control2X = _nextNumber() + offsetX;
      final control2Y = _nextNumber() + offsetY;
      final endX = _nextNumber() + offsetX;
      final endY = _nextNumber() + offsetY;

      _currentSegments.add(
        SvgContourSegment.cubic(
          start: SvgPoint(startX, startY),
          control1: control1,
          control2: SvgPoint(control2X, control2Y),
          end: SvgPoint(endX, endY),
        ),
      );

      _cursorX = endX;
      _cursorY = endY;
      _lastCubicControl = SvgPoint(control2X, control2Y);
      _lastQuadraticControl = null;
      _lastCommandType = _PathCommandType.smoothCubic;
    }
  }

  void _handleSmoothQuadratic({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;
      final offsetX = isRelative ? _cursorX : 0;
      final offsetY = isRelative ? _cursorY : 0;

      final control1 = _reflectedQuadraticControl();
      final endX = _nextNumber() + offsetX;
      final endY = _nextNumber() + offsetY;

      _currentSegments.add(
        SvgContourSegment.quadratic(
          start: SvgPoint(startX, startY),
          control1: control1,
          end: SvgPoint(endX, endY),
        ),
      );

      _cursorX = endX;
      _cursorY = endY;
      _lastQuadraticControl = control1;
      _lastCubicControl = null;
      _lastCommandType = _PathCommandType.smoothQuadratic;
    }
  }

  void _handleArc({required bool isRelative}) {
    while (_hasNumberNext()) {
      final startX = _cursorX;
      final startY = _cursorY;

      final rx = _nextNumber();
      final ry = _nextNumber();
      final xAxisRotation = _nextNumber();
      final largeArc = _nextFlag();
      final sweep = _nextFlag();

      final offsetX = isRelative ? _cursorX : 0;
      final offsetY = isRelative ? _cursorY : 0;
      final endX = _nextNumber() + offsetX;
      final endY = _nextNumber() + offsetY;

      _currentSegments.add(
        SvgContourSegment.arc(
          start: SvgPoint(startX, startY),
          end: SvgPoint(endX, endY),
          rx: rx,
          ry: ry,
          xAxisRotation: xAxisRotation,
          largeArc: largeArc,
          sweep: sweep,
        ),
      );

      _cursorX = endX;
      _cursorY = endY;
      _clearPreviousControls();
      _lastCommandType = _PathCommandType.arc;
    }
  }

  void _handleClose() {
    if (_currentSegments.isNotEmpty) {
      _contours.add(
        SvgContour(
          segments: List.unmodifiable(_currentSegments),
          isClosed: true,
        ),
      );
    }
    _cursorX = _contourStartX;
    _cursorY = _contourStartY;
    _currentSegments = [];
    _clearPreviousControls();
    _lastCommandType = _PathCommandType.close;
  }

  void _finalizeOpenContour() {
    if (_currentSegments.isNotEmpty) {
      _contours.add(
        SvgContour(
          segments: List.unmodifiable(_currentSegments),
          isClosed: false,
        ),
      );
      _currentSegments = [];
    }
  }

  // -- Token stream helpers --

  double _nextNumber() {
    if (_position >= _tokens.length) {
      throw FormatException(
        'Unexpected end of path data: expected a number at position $_position',
      );
    }
    final value = double.tryParse(_tokens[_position]);
    if (value == null) {
      throw FormatException(
        'Expected a number but found "${_tokens[_position]}" '
        'at token position $_position',
      );
    }
    _position += 1;
    return value;
  }

  bool _nextFlag() => _nextNumber() != 0;

  SvgPoint _reflectedCubicControl() {
    final hasCubicPredecessor =
        _lastCommandType == _PathCommandType.cubic ||
        _lastCommandType == _PathCommandType.smoothCubic;
    if (!hasCubicPredecessor || _lastCubicControl == null) {
      return SvgPoint(_cursorX, _cursorY);
    }
    return SvgPoint(
      2 * _cursorX - _lastCubicControl!.x,
      2 * _cursorY - _lastCubicControl!.y,
    );
  }

  SvgPoint _reflectedQuadraticControl() {
    final hasQuadraticPredecessor =
        _lastCommandType == _PathCommandType.quadratic ||
        _lastCommandType == _PathCommandType.smoothQuadratic;
    if (!hasQuadraticPredecessor || _lastQuadraticControl == null) {
      return SvgPoint(_cursorX, _cursorY);
    }
    return SvgPoint(
      2 * _cursorX - _lastQuadraticControl!.x,
      2 * _cursorY - _lastQuadraticControl!.y,
    );
  }

  void _clearPreviousControls() {
    _lastCubicControl = null;
    _lastQuadraticControl = null;
  }

  bool _hasNumberNext() {
    if (_position >= _tokens.length) {
      return false;
    }
    return double.tryParse(_tokens[_position]) != null;
  }
}

enum _PathCommandType {
  move,
  line,
  cubic,
  smoothCubic,
  quadratic,
  smoothQuadratic,
  arc,
  close,
}
