import '../domain/config.dart';
import 'step.dart';
import 'state.dart';

/// Sequential pipeline that runs generation steps in order.
class GenerationPipeline {
  GenerationPipeline(this._steps);

  final List<GenerationStep> _steps;

  /// Ordered list of step identifiers in this pipeline.
  List<String> get stepIds => _steps.map((step) => step.id).toList();

  /// Runs each configured step and returns the final shared state.
  Future<GenerationState> run(GenerationConfig config) async {
    final state = GenerationState();
    for (final step in _steps) {
      await step.run(config, state);
    }
    return state;
  }
}
