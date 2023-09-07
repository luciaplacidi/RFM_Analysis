SELECT TOP 100 *
FROM sales_data_sample

--Check unique values
SELECT DISTINCT status FROM sales_data_sample
SELECT DISTINCT year_id FROM [dbo].[sales_data_sample]
SELECT DISTINCT PRODUCTLINE FROM [dbo].[sales_data_sample]
SELECT DISTINCT COUNTRY FROM [dbo].[sales_data_sample]
SELECT DISTINCT DEALSIZE FROM [dbo].[sales_data_sample]
SELECT DISTINCT TERRITORY FROM [dbo].[sales_data_sample]

-- Analysis

-- Sales by Product Line
SELECT
	PRODUCTLINE
	,SUM(sales) AS revenue
FROM [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

-- Sales by Year
SELECT
	YEAR_ID
	,SUM(sales) AS revenue
FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 2 DESC

-- Sales by Deal Size
SELECT 
	DEALSIZE
	,SUM(sales) Revenue
FROM [dbo].[sales_data_sample]
GROUP BY  DEALSIZE
ORDER BY 2 DESC

-- What was the best month for sales in a specific year?
SELECT
	MONTH_ID
	,SUM(sales) AS Revenue
	,COUNT(ORDERNUMBER) AS Frequency
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2004
GROUP BY  MONTH_ID
ORDER BY 2 DESC

--Best month for sales each year
WITH MonthlySales AS (
    SELECT
        YEAR_ID
        ,MONTH_ID
        ,SUM(sales) AS Revenue
        ,COUNT(ORDERNUMBER) AS Frequency
        ,ROW_NUMBER() OVER (PARTITION BY YEAR_ID ORDER BY SUM(sales) DESC) AS MonthRank
    FROM [dbo].[sales_data_sample]
    GROUP BY YEAR_ID, MONTH_ID
)

SELECT
    YEAR_ID
    ,MONTH_ID
    ,Revenue
    ,Frequency
FROM MonthlySales
WHERE MonthRank = 1;

-- Which PRODUCTLINE is sold the most during the best months?
SELECT
	MONTH_ID
	,PRODUCTLINE
	,SUM(sales) Revenue
	,COUNT(ORDERNUMBER)
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2004 AND MONTH_ID = 11
GROUP BY  MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC

--What city has the highest number of sales in a specific country
SELECT
	city
	,ROUND(SUM(sales),2) Revenue
FROM [dbo].[sales_data_sample]
WHERE country = 'USA'
GROUP BY city
ORDER 2 DESC

---What is the best product in United States?
SELECT
	country
	,YEAR_ID
	,PRODUCTLINE
	,SUM(sales) Revenue
FROM [dbo].[sales_data_sample]
WHERE country = 'USA'
GROUP BY  country, YEAR_ID, PRODUCTLINE
ORDER BY 4 DESC

-- Most sales by Country
SELECT
	country
	,SUM(sales) Revenue
FROM sales_data_sample
GROUP BY  country
ORDER BY 2 DESC

-- Which products are often sold together
SELECT DISTINCT OrderNumber, STUFF(

	(SELECT ',' + PRODUCTCODE
	FROM [dbo].[sales_data_sample] p
	WHERE ORDERNUMBER IN 
		(
			SELECT ORDERNUMBER
			FROM (
				SELECT ORDERNUMBER, COUNT(*) rn
				FROM [dbo].[sales_data_sample]
				WHERE STATUS = 'Shipped'
				GROUP BY ORDERNUMBER
			)m
			WHERE rn >= 2
		)
		AND p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

FROM [dbo].[sales_data_sample] s
ORDER BY 2 DESC


-- RFM Analysis

DROP TABLE IF EXISTS #rfm
;WITH rfm AS
(
SELECT
    CUSTOMERNAME
    ,SUM(sales) AS monetary_score
    ,COUNT(ORDERNUMBER) AS frequency_score
    ,MAX(ORDERDATE) AS most_recent_purchase
    ,DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM sales_data_sample)) AS recency_score
FROM [dbo].[sales_data_sample]
GROUP BY CUSTOMERNAME
),
rfm_calc AS
(
SELECT r.*,
		NTILE(4) OVER (ORDER BY recency_score DESC) R,
		NTILE(4) OVER (ORDER BY frequency_score) F,
		NTILE(4) OVER (ORDER BY monetary_score) M
	FROM rfm r
)
SELECT 
	c.*, R + F + M AS rfm_cell,
	CAST(R AS VARCHAR) + CAST(F AS VARCHAR) + CAST(M  AS VARCHAR) rfm_cell_string
INTO #rfm
FROM rfm_calc c

SELECT CUSTOMERNAME , R, F, M,
	CASE
		WHEN rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) THEN 'Lost'
		WHEN rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144, 221) THEN 'Need Attention'
		WHEN rfm_cell_string in (311, 411, 331, 421, 412) THEN 'Recent Customer'
		WHEN rfm_cell_string in (222, 223, 233, 322, 232, 234) THEN 'Potential Loyalist'
		WHEN rfm_cell_string in (323, 333,321, 422, 332, 432, 423) THEN 'Loyal'
		WHEN rfm_cell_string in (433, 434, 443, 444) THEN 'Champion'
	END rfm_segment

FROM #rfm
