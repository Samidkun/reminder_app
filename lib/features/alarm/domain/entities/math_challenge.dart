import 'dart:math';

class MathChallenge {
  final int num1;
  final int num2;
  final String operation;
  final int result;

  MathChallenge({
    required this.num1,
    required this.num2,
    required this.operation,
    required this.result,
  });

  factory MathChallenge.generate() {
    final random = Random();
    final num1 = random.nextInt(50) + 1;
    final num2 = random.nextInt(50) + 1;
    
    // Simple addition challenge
    return MathChallenge(
      num1: num1,
      num2: num2,
      operation: '+',
      result: num1 + num2,
    );
  }

  bool verify(int answer) {
    return answer == result;
  }
}
