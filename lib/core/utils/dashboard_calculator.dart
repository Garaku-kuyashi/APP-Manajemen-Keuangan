class DashboardCalculator {

  static double? changePercentage(int current, int previous) {
  if (previous == 0) return null;

  return (current - previous) / previous * 100;
}

}