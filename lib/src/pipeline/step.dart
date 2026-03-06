import '../domain/config.dart';
import 'state.dart';

abstract interface class GenerationStep {
  String get id;

  Future<void> run(GenerationConfig config, GenerationState state);
}
