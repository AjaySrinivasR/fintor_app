const MERCHANT_KEYWORDS = {
  'Food & Dining': ['swiggy', 'zomato', 'blinkit', 'zepto', 'instamart', 'mcdonald', 'kfc', 'dominos', 'pizza', 'burger', 'biriyani', 'biryani', 'starbucks', 'cafe', 'coffee', 'tea', 'bakery', 'restaurant', 'dine', 'eats', 'subway', 'canteen'],
  'Dining Out': ['swiggy', 'zomato', 'restaurant', 'cafe', 'dominos', 'mcdonald', 'kfc', 'starbucks', 'dine', 'burger', 'pizza'],
  'Travel & Fuel': ['uber', 'ola', 'rapido', 'petrol', 'fuel', 'hpcl', 'bpcl', 'ioc', 'iocl', 'shell', 'irctc', 'railway', 'train', 'metro', 'fastag', 'toll', 'flight', 'indigo', 'spicejet', 'airindia', 'redbus', 'taxi', 'cab', 'auto', 'makemytrip'],
  Transportation: ['uber', 'ola', 'rapido', 'irctc', 'petrol', 'fuel', 'metro', 'fastag', 'parking', 'flight'],
  Shopping: ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'tata cliq', 'croma', 'reliance', 'dmart', 'bigbasket', 'supermarket', 'mart', 'store', 'retail', 'mall', 'ikea', 'zara', 'h&m', 'decathlon', 'uniqlo', 'lenskart', 'pharmacy', 'apollo'],
  Groceries: ['bigbasket', 'dmart', 'grocery', 'grofers', 'reliance fresh', 'more supermarket', 'jiomart', 'blinkit', 'zepto', 'instamart'],
  Entertainment: ['netflix', 'spotify', 'hotstar', 'disney', 'prime video', 'prime', 'pvr', 'inox', 'cinepolis', 'bookmyshow', 'youtube', 'sony liv', 'zee5', 'gaming', 'cinema', 'movie'],
  'Utilities & Bills': ['airtel', 'jio', 'vi', 'vodafone', 'bescom', 'tneb', 'msedcl', 'bsnl', 'tata play', 'tata sky', 'dish tv', 'dth', 'broadband', 'electricity', 'water bill', 'gas bill', 'recharge', 'billdesk', 'bbps', 'postpaid', 'prepaid', 'insurance', 'lic'],
  Utilities: ['electricity', 'bescom', 'airtel', 'jio', 'vodafone', 'water bill', 'gas bill', 'broadband', 'dth', 'recharge', 'tata play'],
  'Investments & SIP': ['zerodha', 'groww', 'upstox', 'coin', 'kuvera', 'mutual fund', 'sip', 'kite', 'angelone', '5paisa', 'indmoney', 'smallcase', 'nse', 'bse', 'navi', 'etmoney', 'investment'],
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
