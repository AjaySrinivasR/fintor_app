const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Make sure the upload folders exist (they're git-ignored, so a fresh
// clone won't have them until this runs once)
['uploads/receipts', 'uploads/csv'].forEach((dir) => {
  const fullPath = path.join(__dirname, '..', dir);
  if (!fs.existsSync(fullPath)) fs.mkdirSync(fullPath, { recursive: true });
});

// Receipt images — stored purely as a static file, no OCR/parsing.
// We just need a URL we can save on the Expense document.
const receiptStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '../uploads/receipts')),
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const receiptFileFilter = (req, file, cb) => {
  const allowed = ['image/jpeg', 'image/png', 'image/webp'];
  if (allowed.includes(file.mimetype)) return cb(null, true);
  cb(new Error('Only JPEG, PNG, or WEBP images are allowed for receipts'));
};

const uploadReceipt = multer({
  storage: receiptStorage,
  fileFilter: receiptFileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// CSV bulk import — bank statement / expense CSV files
const csvStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '../uploads/csv')),
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const csvFileFilter = (req, file, cb) => {
  const allowed = ['text/csv', 'application/vnd.ms-excel'];
  if (allowed.includes(file.mimetype) || file.originalname.toLowerCase().endsWith('.csv')) {
    return cb(null, true);
  }
  cb(new Error('Only .csv files are allowed for bulk import'));
};

const uploadCsv = multer({
  storage: csvStorage,
  fileFilter: csvFileFilter,
  limits: { fileSize: 2 * 1024 * 1024 }, // 2MB
});

module.exports = {
  uploadReceipt,
  uploadCsv,
};
