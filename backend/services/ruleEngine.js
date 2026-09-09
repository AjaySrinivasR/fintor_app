const generateInsights = (expenses, budgets) => {
  const tips = [];
  const categoryTotals = {};
  let totalSpent = 0;
  let totalIncome = 0;

  expenses.forEach((e) => {
    if (e.type === 'debit') {
      categoryTotals[e.category] = (categoryTotals[e.category] || 0) + e.amount;
      totalSpent += e.amount;
    } else if (e.type === 'credit') {
      totalIncome += e.amount;
    }
  });

  // Category Limit Checks
  budgets.forEach((budget) => {
    const spent = categoryTotals[budget.category] || 0;
    const ratio = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100 : 0;

    if (spent >= budget.limitAmount) {
      tips.push({
        title: `${budget.category} Budget Exceeded`,
        message: `You spent ₹${spent.toFixed(0)} against a limit of ₹${budget.limitAmount.toFixed(0)}.`,
        type: 'alert',
        impactAmount: spent - budget.limitAmount,
      });
    } else if (ratio >= 80) {
      tips.push({
        title: `${budget.category} Limit Nearing`,
        message: `You have consumed ${ratio.toFixed(0)}% of your limit for ${budget.category}.`,
        type: 'warning',
        impactAmount: budget.limitAmount - spent,
      });
    }
  });

  // Macro 50/30/20 Rule
  if (totalIncome > 0) {
    const savingsRate = ((totalIncome - totalSpent) / totalIncome) * 100;
    if (savingsRate >= 20) {
      tips.push({
        title: 'Strong Savings Rate',
        message: `You are saving ${savingsRate.toFixed(0)}% of total inflow this month.`,
        type: 'success',
      });
    } else if (savingsRate < 10 && savingsRate >= 0) {
      tips.push({
        title: 'Low Net Savings',
        message: `Your savings rate is currently ${savingsRate.toFixed(0)}%. Aim for 20%.`,
        type: 'warning',
      });
    }
  }

  return tips;
};

module.exports = { generateInsights };