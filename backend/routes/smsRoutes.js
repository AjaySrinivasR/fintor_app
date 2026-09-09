const express = require('express');
const router = express.Router();

const BANK_TEMPLATES = [
    // Append into BANK_TEMPLATES in backend/routes/smsRoutes.js
    {
        bank: 'TMB / Universal Inverted',
        senderPattern: '.*(TMB|AXIS|OKAXIS|BANK).*',
        debitRegex: '(?:a\\/c.*?(?:is\\s+)?debited.*?Rs\\.?\\s*([\\d,]+\\.?\\d*)|Rs\\.?\\s*([\\d,]+\\.?\\d*)\\s*(?:is\\s+)?debited)',
        creditRegex: '(?:a\\/c.*?(?:is\\s+)?credited.*?Rs\\.?\\s*([\\d,]+\\.?\\d*)|Rs\\.?\\s*([\\d,]+\\.?\\d*)\\s*(?:is\\s+)?credited)',
        amountGroup: 1,
        accountGroup: 0,
        merchantGroup: 0
    },
    {
        bank: 'HDFC',
        senderPattern: '.*(HDFC|HDFCBK).*',
        debitRegex: '(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)\\s*(?:debited|spent).*?A\\/c.*?(?:[xX*]*(\\d{3,4})).*?(?:to|at|info)\\s+([A-Za-z0-9@._\\s\\-]+?)(?:\\.|\\s+on|\\s+avail|\\z)',
        creditRegex: '(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)\\s*(?:credited|deposited).*?A\\/c.*?(?:[xX*]*(\\d{3,4}))',
        amountGroup: 1,
        accountGroup: 2,
        merchantGroup: 3,
    },
    {
        bank: 'SBI',
        senderPattern: '.*(SBI|SBINB).*',
        debitRegex: '(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)\\s*(?:debited from|transferred from).*?(?:a\\/c|acct).*?([xX*]*(\\d{4})).*?(?:to|towards)\\s+([A-Za-z0-9@._\\s\\-]+?)(?:\\.|\\s+Ref|\\z)',
        creditRegex: '(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*)\\s*(?:credited to).*?(?:a\\/c|acct).*?([xX*]*(\\d{4}))',
        amountGroup: 1,
        accountGroup: 2,
        merchantGroup: 3,
    },
    {
        bank: 'ICICI',
        senderPattern: '.*(ICICI|ICICIB).*',
        debitRegex: '(?:debited with|spent)\\s*(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*).*?(?:A\\/c|Card).*?([xX*]*(\\d{4})).*?(?:at|to|info)\\s+([A-Za-z0-9@._\\s\\-]+?)(?:\\.|\\s+on|\\z)',
        creditRegex: '(?:credited with)\\s*(?:Rs\\.?|INR)\\s*([\\d,]+\\.?\\d*).*?(?:A\\/c).*?([xX*]*(\\d{4}))',
        amountGroup: 1,
        accountGroup: 2,
        merchantGroup: 3,
    },
];

router.get('/templates', (req, res) => {
    res.status(200).json({
        success: true,
        version: '2026.09.1',
        templates: BANK_TEMPLATES,
    });
});

module.exports = router;