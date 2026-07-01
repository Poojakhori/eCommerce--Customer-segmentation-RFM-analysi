Create database Ecommerce;
Use Ecommerce;

Create table OnlineRetail
(
InvoiceNo VARCHAR(20),
StockCode VARCHAR(20),
Description VARCHAR(255),
Quantity INT,
InvoiceDate DATETIME,
UnitPrice DECIMAL(10,2),
CustomerID INT,
Country VARCHAR(100)
);

DESCRIBE onlineretail;
CREATE TABLE onlineretail_stage (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(30),
    UnitPrice DECIMAL(10,2),
    CustomerID VARCHAR(20),
    Country VARCHAR(100)
);
truncate table onlineretail;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.1/Uploads/data_clean.csv'
INTO TABLE onlineretail
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
InvoiceNo,
StockCode,
Description,
Quantity,
@InvoiceDate,
UnitPrice,
@CustomerID,
Country
)
SET
InvoiceDate = NULLIF(@InvoiceDate,''),
CustomerID = NULLIF(@CustomerID,'');

SHOW WARNINGS;

SELECT COUNT(*) AS TotalRows
FROM onlineretail;

SELECT
COUNT(*) AS TotalRows,
COUNT(CustomerID) AS CustomerIDs,
COUNT(*) - COUNT(CustomerID) AS MissingCustomerIDs
FROM onlineretail;

SELECT *
FROM onlineretail;

‪-- Check for Duplicate Records
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    COUNT(*) AS Duplicate_Count
FROM onlineretail
GROUP BY
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
HAVING COUNT(*) > 1;

-- 
SELECT COUNT(*) AS Duplicate_Rows
FROM (
    SELECT
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country,
        COUNT(*) AS cnt
    FROM onlineretail
    GROUP BY
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country
    HAVING COUNT(*) > 1
) d;

--
SELECT *
FROM onlineretail
WHERE InvoiceNo LIKE 'C%';
SELECT COUNT(*) AS Cancelled_Orders
FROM onlineretail
WHERE InvoiceNo LIKE 'C%';

SELECT *
FROM onlineretail
WHERE Quantity < 0;

SELECT COUNT(*) AS Negative_Quantity
FROM onlineretail
WHERE Quantity < 0;
SELECT COUNT(*) AS Invalid_Price
FROM onlineretail
WHERE UnitPrice <= 0;
SELECT *
FROM onlineretail
WHERE CustomerID IS NULL;
SELECT COUNT(*) AS Missing_CustomerID
FROM onlineretail
WHERE CustomerID IS NULL;

SELECT
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END) AS Cancelled_Orders,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS Negative_Quantity,
    SUM(CASE WHEN UnitPrice <= 0 THEN 1 ELSE 0 END) AS Invalid_Price,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID
FROM onlineretail;

CREATE TABLE onlineretail_clean AS
SELECT *
FROM onlineretail
WHERE
    InvoiceNo NOT LIKE 'C%'
    AND Quantity > 0
    AND UnitPrice > 0
    AND CustomerID IS NOT NULL;
    
    SELECT COUNT(*) AS Cleaned_Rows
FROM onlineretail_clean;

SELECT
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END) AS Cancelled_Orders,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS Negative_Quantity,
    SUM(CASE WHEN UnitPrice <= 0 THEN 1 ELSE 0 END) AS Invalid_Price,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID
FROM onlineretail_clean;

-- 1. Customer Summary using CTE (Bussiness Insights: total orders, total revenue, last purchase date)
WITH CustomerSales AS
(
SELECT
CustomerID,

MAX(InvoiceDate) AS LastPurchase,

COUNT(DISTINCT InvoiceNo) AS Frequency,

SUM(Quantity * UnitPrice) AS Monetary

FROM onlineretail_clean

WHERE CustomerID IS NOT NULL
AND Quantity > 0

GROUP BY CustomerID
)

SELECT *
FROM CustomerSales;

-- Calculate Recency (Lower Recency = Better Customer)
WITH CustomerSales AS
(
SELECT

CustomerID,

DATEDIFF(
(SELECT MAX(InvoiceDate) FROM onlineretail_clean),
MAX(InvoiceDate)
) AS Recency,

COUNT(DISTINCT InvoiceNo) AS Frequency,

SUM(Quantity*UnitPrice) Monetary

FROM onlineretail_clean

GROUP BY CustomerID
)

SELECT *
FROM CustomerSales;
-- RFM Scoring using NTILE()
WITH CustomerSales AS
(
SELECT

CustomerID,

DATEDIFF(
(SELECT MAX(InvoiceDate) FROM onlineretail_clean),
MAX(InvoiceDate)
) Recency,

COUNT(DISTINCT InvoiceNo) Frequency,

SUM(Quantity*UnitPrice) Monetary

FROM onlineretail_clean

GROUP BY CustomerID
),

RFM AS
(

SELECT *,

NTILE(5) OVER(ORDER BY Recency DESC) AS R_Score,

NTILE(5) OVER(ORDER BY Frequency) AS F_Score,

NTILE(5) OVER(ORDER BY Monetary) AS M_Score

FROM CustomerSales

)
SELECT *
FROM RFM;

-- Overall RFM Score

WITH CustomerSales AS
(
SELECT

CustomerID,

DATEDIFF(
(SELECT MAX(InvoiceDate) FROM onlineretail_clean),
MAX(InvoiceDate)
) Recency,

COUNT(DISTINCT InvoiceNo) Frequency,

SUM(Quantity*UnitPrice) Monetary

FROM onlineretail_clean

GROUP BY CustomerID
),

RFM AS
(

SELECT *,

NTILE(5) OVER(ORDER BY Recency DESC) R,

NTILE(5) OVER(ORDER BY Frequency) F,

NTILE(5) OVER(ORDER BY Monetary) M

FROM CustomerSales

)

SELECT *,

CONCAT(R,F,M) AS RFM_Score

FROM RFM;

-- Customer Segmentation (VIP Buyers, loyal customers, regular customers, at risk customers, dormant users)
WITH CustomerSales AS
(
SELECT

CustomerID,

DATEDIFF(
(SELECT MAX(InvoiceDate) FROM onlineretail_clean),
MAX(InvoiceDate)
) Recency,

COUNT(DISTINCT InvoiceNo) Frequency,

SUM(Quantity*UnitPrice) Monetary

FROM onlineretail_clean

GROUP BY CustomerID
),

RFM AS
(

SELECT *,

NTILE(5) OVER(ORDER BY Recency DESC) R,

NTILE(5) OVER(ORDER BY Frequency) F,

NTILE(5) OVER(ORDER BY Monetary) M

FROM CustomerSales

)

SELECT *,

CASE

WHEN R>=4 AND F>=4 AND M>=4
THEN 'VIP Customer'

WHEN R>=4 AND F>=3
THEN 'Loyal Customer'

WHEN R<=2 AND F>=3
THEN 'At Risk'

WHEN R=1 AND F<=2
THEN 'Dormant'

ELSE 'Regular'

END AS CustomerSegment

FROM RFM;

-- Count Customers by Segment
WITH CustomerSales AS
(
SELECT
    CustomerID,
    DATEDIFF(
        (SELECT MAX(InvoiceDate) FROM onlineretail_clean),
        MAX(InvoiceDate)
    ) AS Recency,
    COUNT(DISTINCT InvoiceNo) AS Frequency,
    SUM(Quantity * UnitPrice) AS Monetary
FROM onlineretail_clean
GROUP BY CustomerID
),

RFM AS
(
SELECT *,
    NTILE(5) OVER(ORDER BY Recency DESC) AS R,
    NTILE(5) OVER(ORDER BY Frequency) AS F,
    NTILE(5) OVER(ORDER BY Monetary) AS M
FROM CustomerSales
),

CustomerSegments AS
(
SELECT
    CustomerID,
    Monetary,
    CASE
        WHEN R>=4 AND F>=4 AND M>=4 THEN 'VIP Customer'
        WHEN R>=4 AND F>=3 THEN 'Loyal Customer'
        WHEN R<=2 AND F>=3 THEN 'At Risk'
        WHEN R=1 AND F<=2 THEN 'Dormant'
        ELSE 'Regular'
    END AS CustomerSegment
FROM RFM
)

SELECT
    CustomerSegment,
    COUNT(*) AS TotalCustomers
FROM CustomerSegments
GROUP BY CustomerSegment

-- Revenue by Segment

ORDER BY TotalCustomers DESC;

-- 

WITH CustomerSales AS
(
SELECT
    CustomerID,
    DATEDIFF(
        (SELECT MAX(InvoiceDate) FROM onlineretail_clean),
        MAX(InvoiceDate)
    ) AS Recency,
    COUNT(DISTINCT InvoiceNo) AS Frequency,
    SUM(Quantity * UnitPrice) AS Monetary
FROM onlineretail_clean
GROUP BY CustomerID
),

RFM AS
(
SELECT *,
    NTILE(5) OVER(ORDER BY Recency DESC) AS R,
    NTILE(5) OVER(ORDER BY Frequency) AS F,
    NTILE(5) OVER(ORDER BY Monetary) AS M
FROM CustomerSales
),

CustomerSegments AS
(
SELECT
    CustomerID,
    Monetary,
    CASE
        WHEN R>=4 AND F>=4 AND M>=4 THEN 'VIP Customer'
        WHEN R>=4 AND F>=3 THEN 'Loyal Customer'
        WHEN R<=2 AND F>=3 THEN 'At Risk'
        WHEN R=1 AND F<=2 THEN 'Dormant'
        ELSE 'Regular'
    END AS CustomerSegment
FROM RFM
)

SELECT
    CustomerSegment,
    ROUND(SUM(Monetary),2) Revenue

FROM CustomerSegments

GROUP BY CustomerSegment

ORDER BY Revenue DESC;
-- Rank Top Customers
WITH CustomerSales AS
(
SELECT

CustomerID,

SUM(Quantity*UnitPrice) Revenue

FROM onlineretail_clean

GROUP BY CustomerID
)

SELECT *

FROM

(
SELECT *,

DENSE_RANK() OVER(ORDER BY Revenue DESC) RankNo

FROM CustomerSales
) A

WHERE RankNo<=10;
-- Monthly Sales Trend
SELECT

DATE_FORMAT(InvoiceDate,'%Y-%m') AS Month,

ROUND(SUM(Quantity*UnitPrice),2) Revenue

FROM onlineretail_clean

GROUP BY Month

ORDER BY Month;

-- Monthly Active Customers
SELECT

DATE_FORMAT(InvoiceDate,'%Y-%m') Month,

COUNT(DISTINCT CustomerID) ActiveCustomers

FROM onlineretail_clean

GROUP BY Month

ORDER BY Month;

-- Cohort Analysis
WITH FirstPurchase AS
(
SELECT

CustomerID,

MIN(DATE_FORMAT(InvoiceDate,'%Y-%m')) FirstMonth

FROM onlineretail_clean

GROUP BY CustomerID
)

SELECT *

FROM FirstPurchase;

-- Cohort Retention Table
WITH FirstPurchase AS
(
SELECT

CustomerID,

MIN(DATE_FORMAT(InvoiceDate,'%Y-%m')) CohortMonth

FROM onlineretail_clean

GROUP BY CustomerID
)

SELECT

fp.CohortMonth,

DATE_FORMAT(o.InvoiceDate,'%Y-%m') OrderMonth,

COUNT(DISTINCT o.CustomerID) Customers

FROM onlineretail_clean o

JOIN FirstPurchase fp

ON o.CustomerID=fp.CustomerID

GROUP BY
fp.CohortMonth,
OrderMonth

ORDER BY
fp.CohortMonth,
OrderMonth;
