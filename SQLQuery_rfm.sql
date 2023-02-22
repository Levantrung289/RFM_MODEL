GO
IF  EXISTS(SELECT * FROM INFORMATION_SCHEMA.VIEWS Where Table_Name ='rfm_group')
BEGIN
     DROP VIEW rfm_group
END
GO
CREATE VIEW rfm_group AS

-- Amount of customer from United Kingdom

WITH dt_unitedkingdom AS
(
SELECT *, [Amount] = UnitPrice * Quantity
FROM customer_db 
WHERE Country = 'United Kingdom' AND UnitPrice > 0 AND Quantity > 0
),

dt_rfm as (
	SELECT customer_id, MAX([Date]) AS [last_active], DATEDIFF(DAY, MAX([Date]), GETDATE()) AS [Recency],
	COUNT(DATE) AS [Frequency], SUM(Amount) as [Monetary]
	FROM dt_unitedkingdom
	GROUP BY customer_id
),
-- Recency, Frequency, Monetary have 3 levels: 1 , 2 , 3
-- Customer recency level is 0 - 60 days has 3 points, 60-200 has 2 points, else has 1 point
-- 20% customers contribute 80% revenue so that TOP 20% customers Frequency and Monetary
-- have 3 point, 30% customers have 2 point, 50% customer have 1 point
-- Recency: 1-Churned, 2-churning, 3-active
-- Frequency: 1-Least Frequent, 2-Frequent, 3-Most Frequent
-- Monetary: 1-Least spending, 2-Normal spending, 3-Most spending

dt_rfm_rank as (
SELECT *,ROUND(PERCENT_RANK() OVER(ORDER BY Frequency),1) as [frequency_rank]
		,ROUND(PERCENT_RANK() OVER(ORDER BY Monetary),1) as [monetary_rank]
FROM dt_rfm
),
dt_rfm_segment as (
SELECT *,
CASE
	WHEN Recency < 60 THEN 3
	WHEN Recency BETWEEN 60 AND 200 THEN 2
	WHEN Recency > 200 THEN 1
	END AS [recency_segment],
CASE
	WHEN frequency_rank > 0.8 THEN 3
	WHEN frequency_rank BETWEEN 0.5 AND 0.8 THEN 2
	WHEN frequency_rank < 0.5 THEN 1
	END AS [frequency_segment],
CASE
	WHEN monetary_rank > 0.8 THEN 3
	WHEN monetary_rank BETWEEN 0.5 AND 0.8 THEN 2
	WHEN monetary_rank < 0.5 THEN 1
	END AS [monetary_segment]
FROM dt_rfm_rank
),
dt_rfm_concat as (
SELECT * ,rfm_segment = CONCAT(recency_segment,frequency_segment,monetary_segment)
FROM dt_rfm_segment
)
-- Sengmentation 
-- Champions: Bought recently, buy often and spend the most! : 333
-- Loyal Customers: Spend good money with us often. Responsive to promotions: 332, 322, 323
-- Potential Loyalist: Recent customers, but spent a good amount and bought more than once: 313
-- Recent Customers: Bought most recently, but not often: 311, 312 
-- Promising: Recent shoppers, but haven’t spent much :321, 331
-- Customers Needing Attention: Above average recency, frequency and monetary values. 
-- May not have bought very recently though: 222, 232, 231
-- About To Sleep: Below average recency, frequency and monetary values.
-- Will lose them if not reactivated: 211, 221, 212, 131, 132
-- At Risk: Spent big money and purchased often. But long time ago. Need to bring them back!: 122
-- Can’t Lose Them: Made biggest purchases, and often. 
-- But haven’t returned for a long time.: 123 , 113, 133, 213, 223, 233 
-- Hibernating: Last purchase was long back, low spenders and low number of orders: 112, 121
-- Lost: Lowest recency, frequency and monetary scores.: 111
SELECT *, rfm_group = 
CASE
	WHEN rfm_segment = '333' THEN 'Champions'
	WHEN rfm_segment IN ('332', '322', '323') THEN 'Loyal Customers'
	WHEN rfm_segment ='313' THEN 'Potential Loyalist'
	WHEN rfm_segment IN ('311', '312') THEN 'Recent Customers'
	WHEN rfm_segment IN ('321', '331') THEN 'Promising'
	WHEN rfm_segment IN ('222', '232', '231') THEN 'Customers Needing Attentions'
	WHEN rfm_segment IN ('211', '221', '212', '131', '132') THEN 'About To Sleep'
	WHEN rfm_segment ='122' THEN 'At Risk'
	WHEN rfm_segment IN ('123' , '113', '133', '213', '223', '233') THEN 'Can’t Lose Them'
	WHEN rfm_segment IN ('112', '121') THEN 'Hibernating'
	WHEN rfm_segment = '111' THEN 'Lost'
	END
FROM dt_rfm_concat
