class UserModel {
  final String id;
  final String name;
  final String email;
  final double monthlyIncome;
  final double liquidReserves;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.monthlyIncome = 50000,
    this.liquidReserves = 100000,
  });
}
