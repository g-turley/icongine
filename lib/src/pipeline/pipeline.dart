import '../domain/config.dart';
import 'step.dart';
import 'state.dart';

class GenerationPipeline {
  GenerationPipeline(this._steps);

  final List<GenerationStep> _steps;

  List<String> get stepIds => _steps.map((step) => step.id).toList();

  Future<GenerationState> run(GenerationConfig config) async {
    final state = GenerationState();
    for (final step in _steps) {
      await step.run(config, state);
    }
    return state;
  }
}
