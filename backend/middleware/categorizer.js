const MERCHANT_KEYWORDS = {
  Groceries: ['bigbasket', 'dmart', 'grocery', 'grofers', 'reliance fresh', 'more supermarket', 'jiomart'],
  'Dining Out': ['swiggy', 'zomato', 'restaurant', 'cafe', 'dominos', 'mcdonald', 'kfc', 'starbucks', 'dine'],
  Entertainment: ['netflix', 'spotify', 'prime video', 'hotstar', 'bookmyshow', 'pvr', 'inox', 'cinema'],
  Utilities: ['electricity', 'bescom', 'airtel', 'jio', 'vodafone', 'water bill', 'gas bill', 'broadband', 'dth'],
  Transportation: ['uber', 'ola', 'rapido', 'irctc', 'petrol', 'fuel', 'metro', 'fastag', 'parking'],
};

/**
 * @param {string} merchant - raw merchant/description text from a CSV row or statement line
 * @param {Array<{_id, name}>} userCategories - the user's actual Category documents
 * @returns {string|null} matching category _id or null if nothing matched
 */
const guessCategory = (merchant, userCategories) => {
  if (!merchant || !userCategories) return null;
  const merchantLower = merchant.toLowerCase();

  for (const category of userCategories) {
    const keywords = MERCHANT_KEYWORDS[category.name];
    if (!keywords) continue;
    if (keywords.some((kw) => merchantLower.includes(kw))) {
      return category._id;
    }
  }
  return null;
};

module.exports = {
  MERCHANT_KEYWORDS,
  guessCategory,
};
