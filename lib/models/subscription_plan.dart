class SubscriptionPlan {
  final String name;
  final double price;
  final int maxCompanies;
  final int maxEmployeesPerCompany;
  final int maxMonthlyDownloads;
  final bool isUnlimited;

  const SubscriptionPlan({
    required this.name,
    required this.price,
    required this.maxCompanies,
    required this.maxEmployeesPerCompany,
    required this.maxMonthlyDownloads,
    this.isUnlimited = false,
  });

  static const free = SubscriptionPlan(
    name: 'Free',
    price: 0.0,
    maxCompanies: 1,
    maxEmployeesPerCompany: 5,
    maxMonthlyDownloads: 5,
  );

  static const trial = SubscriptionPlan(
    name: 'Trial',
    price: 0.0,
    maxCompanies: 999,
    maxEmployeesPerCompany: 999,
    maxMonthlyDownloads: 999,
    isUnlimited: true,
  );

  static const contador = SubscriptionPlan(
    name: 'Contador & Pymes',
    price: 15.0,
    maxCompanies: 3,
    maxEmployeesPerCompany: 20,
    maxMonthlyDownloads: 100,
  );

  static const businessPro = SubscriptionPlan(
    name: 'Business Pro',
    price: 70.0,
    maxCompanies: 9999,
    maxEmployeesPerCompany: 9999,
    maxMonthlyDownloads: 9999,
    isUnlimited: true,
  );
}
