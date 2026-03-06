import '../domain/config.dart';
import 'state.dart';

/// A single stage in the icon generation pipeline.
abstract interface class GenerationStep {
  /// Stable pipeline identifier used in reports.
  String get id;

  /// Executes this pipeline step against [state].
  Future<void> run(GenerationConfig config, GenerationState state);
}
