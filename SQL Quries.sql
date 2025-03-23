#1 Retrieve the number of unique customers by region and their average credit score.

SELECT 
    lr.region, 
    COUNT(DISTINCT l.customer_id) AS unique_customers,
    AVG(CASE WHEN l.grade = 'A' THEN 750 WHEN l.grade = 'B' THEN 700
             WHEN l.grade = 'C' THEN 650 WHEN l.grade = 'D' THEN 600
             WHEN l.grade = 'E' THEN 550 WHEN l.grade = 'F' THEN 500
             ELSE 450 END) AS avg_credit_score
FROM loan l
JOIN loan_with_region lr ON l.loan_id = lr.loan_id
GROUP BY lr.region
ORDER BY unique_customers DESC;


#2Calculate the percentage of Charged off loans out of the total loan applications.

SELECT 
    (SELECT COUNT(loan_status) 
     FROM loan 
     WHERE loan_status = 'Charged Off') 
    / COUNT(loan_status) * 100 AS 
    "Charged Off Loans %"
FROM loan;

#3 Identify loans with high default risk based on credit score, income, and loan amount.

WITH CreditScoreCalc AS (
    SELECT 
        l.loan_id, c.customer_id,
        c.annual_inc, l.loan_amount, l.grade,
        CASE 
            WHEN l.grade = 'A' THEN 750 WHEN l.grade = 'B' THEN 700
            WHEN l.grade = 'C' THEN 650 WHEN l.grade = 'D' THEN 600
            WHEN l.grade = 'E' THEN 550 WHEN l.grade = 'F' THEN 500
            ELSE 450 
        END AS credit_score
    FROM loan l
    JOIN customers c ON l.customer_id = c.customer_id
)
SELECT 
    loan_id,customer_id, annual_inc,
    loan_amount, credit_score,
    CASE 
        WHEN credit_score < 600 AND annual_inc < 40000 AND loan_amount > 
        30000 THEN 'High Risk'
        WHEN (credit_score BETWEEN 600 AND 650) AND (annual_inc BETWEEN 
        40000 AND 70000) 
        AND (loan_amount BETWEEN 20000 AND 50000) THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_category
FROM CreditScoreCalc
ORDER BY risk_category DESC;


#4 Find the top 5 states with the highest loans and compare them to their average loan amount

WITH StateLoanStats AS (
    SELECT 
		c.addr_state AS state, COUNT(*) AS total_loans, ROUND(AVG(l.loan_amount),2) 
        AS avg_loan_amount
    FROM loan l
    JOIN customers c ON l.customer_id = c.customer_id 
    GROUP BY c.addr_state
)
SELECT 
	state, total_loans, avg_loan_amount FROM StateLoanStats 
    ORDER BY total_loans DESC LIMIT 5;
    
    #5 Analyze loan disbursement trends by year and identify the fastest-growing loan categories.

SELECT 
    YEAR(issue_date) AS loan_year, 
    purpose AS loan_category,
    SUM(loan_amount) AS total_disbursed,
    LAG(SUM(loan_amount)) OVER (PARTITION BY purpose ORDER BY YEAR(issue_date)) 
    AS prev_year_disbursed, (SUM(loan_amount) - LAG(SUM(loan_amount)) 
    OVER (PARTITION BY purpose ORDER BY YEAR(issue_date))) * 100.0 / 
    NULLIF(LAG(SUM(loan_amount)) OVER (PARTITION BY purpose ORDER BY YEAR(issue_date)), 0) 
    AS growth_rate
FROM loan
GROUP BY loan_year, purpose
ORDER BY loan_year DESC, growth_rate DESC;


#6 Find the average number of loans taken per customer and their repayment history.

SELECT 
    c.customer_id,
    COUNT(l.loan_id) AS total_loans,
    SUM(CASE WHEN l.loan_status IN ('Fully Paid', 'Current') THEN 1 ELSE 0 END)
    AS repaid_loans,
    SUM(CASE WHEN l.loan_status IN ('Default', 'Charged Off') THEN 1 ELSE 0 END) 
    AS defaulted_loans,
    ROUND(COUNT(l.loan_id) / COUNT(DISTINCT c.customer_id), 2) AS avg_loans_per_customer
FROM customers c
JOIN loan l ON c.customer_id = l.customer_id
GROUP BY c.customer_id;


#7 Retrieve the average interest rate for loans by loan category and region.

SELECT 
    l.purpose AS loan_category,  
    r.region, ROUND(AVG(l.int_rate)*100,2) 
    AS avg_interest_rate  
FROM loan l
JOIN loan_with_region r ON l.loan_id = r.loan_id 
GROUP BY l.purpose, r.region ORDER BY loan_category, region;

#8 Identify the most common loan purposes and their default rates.

SELECT 
    purpose, 
    COUNT(*) AS total_loans,
    COUNT(CASE WHEN loan_status IN ('Charged Off', 'Default') 
    THEN 1 END) 
    * 100.0 / COUNT(*) AS default_rate
FROM loan 
GROUP BY purpose
ORDER BY total_loans DESC;

#9 Find the correlation between income levels and loan Default probability.

SELECT 
    CASE 
        WHEN annual_inc < 40000 THEN 'Low Income'
        WHEN annual_inc BETWEEN 40000 AND 79999 THEN 'Medium Income'
        ELSE 'High Income'
    END AS income_category,
    COUNT(*) AS total_loans,
    SUM(CASE WHEN loan_status IN ('Default', 'Charged Off') THEN 1 ELSE 0 END) 
    AS defaulted_loans,
    ROUND((SUM(CASE WHEN loan_status IN ('Default', 'Charged Off') THEN 1 ELSE 0 END) * 100.0) 
    / COUNT(*), 2) AS default_rate
FROM customers c
JOIN loan l ON c.customer_id = l.customer_id
GROUP BY income_category
ORDER BY default_rate DESC;


#10 List customers who have missed multiple payments and are at risk of default.

SELECT c.customer_id, c.home_ownership,
l.loan_status,
l.loan_id, 
l.type
FROM customers c
JOIN loan l ON c.customer_id = l.customer_id
WHERE l.loan_status = 'Late (31-120 days)';