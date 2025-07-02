📊 Online Retail RFM Analysis (SQL Stage)

This project focuses on cleaning and preparing customer transaction data for RFM (Recency, Frequency, Monetary) analysis using PostgreSQL.

✅ Project Goal
-  Data imported and cleaned using SQL

📁 Data Source
- Dataset: [UCI Online Retail II Dataset](https://archive.ics.uci.edu/ml/datasets/Online+Retail+II)
- Files used: `online_retail_II_2009_2010.csv` and `online_retail_II_2010_2011.csv`

🛠️ Tools Used
- PostgreSQL (via VSCode)
- KNIME (planned for further analysis with no code)
- Tableau (planned for further visualisation)

🧹 Data Cleaning Steps (SQL)
- Merged 2 annual CSV files into a single dataset `retail_full`
- Converted `invoice_date` to proper `DATE` and `TIMESTAMP` types
- Removed rows with:
  - Cancelled invoices (`invoice ~ '^C'`)
  - Negative or zero `quantity` or `price`
- Created a cleaned table: `retail_clean`
- Added a computed column: `invoice_value = quantity * price`

📊 RFM Feature Extraction (SQL)
Created table `customers_rfm` with:
- `customer_value`: total monetary value (sum of invoice_value)
- `frequency`: number of unique invoices
- `recency`: days since last purchase based on max date in dataset

## ⏭️ Next Steps
- Import `customers_rfm` into KNIME
- Normalize RFM columns
- Apply clustering or scoring models
- Export and visualize customer segments
