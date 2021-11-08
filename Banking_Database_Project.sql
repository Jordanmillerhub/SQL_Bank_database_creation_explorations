/*
    Name: <Jordan Miller>
    DTSC660: Data and Database Managment with SQL
    Module 5
    Assignment 4
*/

--------------------------------------------------------------------------------
/*				                 Banking DDL           		  		          */
--------------------------------------------------------------------------------
CREATE TABLE branch (branch_name VARCHAR(40),
branch_city VARCHAR(20),
assets NUMERIC(15,2) CHECK (assets>0.00),
CONSTRAINT branch_pkey PRIMARY KEY (branch_name)
);
  
CREATE TABLE customer (cust_ID VARCHAR(15),
customer_name VARCHAR(25) NOT NULL,
customer_street VARCHAR(30),
customer_city VARCHAR(20),
CONSTRAINT customer_pkey PRIMARY KEY (cust_ID)
);
  
CREATE TABLE loan (loan_number VARCHAR(15),
branch_name VARCHAR(40),
amount NUMERIC(12,2),
CONSTRAINT loan_pkey PRIMARY KEY (loan_number),
CONSTRAINT loan_fkey FOREIGN KEY (branch_name) REFERENCES branch (branch_name)
--want to keep data on delete to see branch of origin.
);
  
CREATE TABLE borrower (cust_ID VARCHAR(15),
loan_number VARCHAR(15),
CONSTRAINT borrower_pkey PRIMARY KEY (cust_ID,loan_number),
CONSTRAINT borrower_fkey_1 FOREIGN KEY (cust_ID) REFERENCES customer (cust_ID)
ON DELETE CASCADE
ON UPDATE CASCADE,
CONSTRAINT borrower_fkey_2 FOREIGN KEY (loan_number) REFERENCES loan (loan_number)
ON DELETE CASCADE
ON UPDATE CASCADE
);
  
CREATE TABLE account (account_number VARCHAR(15),
branch_name VARCHAR(40),
balance NUMERIC(12,2) DEFAULT 0.00,
CONSTRAINT account_pkey PRIMARY KEY (account_number),
CONSTRAINT account_fkey FOREIGN KEY (branch_name) REFERENCES branch (branch_name)
);
  
CREATE TABLE depositor (cust_ID VARCHAR(15),
account_number VARCHAR(15),
CONSTRAINT depositor_pkey PRIMARY KEY (cust_ID, account_number),
CONSTRAINT depositor_fkey FOREIGN KEY (cust_ID) REFERENCES customer (cust_ID)
ON DELETE CASCADE
ON UPDATE CASCADE
);

--------------------------------------------------------------------------------
--function to calculate monthly payment taking in principal, apr, and length of loan
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION Miller_24_monthlyPayment(iPrincipal NUMERIC(12,2),
apr NUMERIC(7,6),
years INTEGER)
RETURNS NUMERIC(12,2)
LANGUAGE PLPGSQL
AS
$$
DECLARE
monthlyPayment NUMERIC(12,2);   
monthlyIntRate NUMERIC(7,6);
totNumPayments INTEGER;
BEGIN
monthlyIntRate = apr / 12;
totNumPayments = years * 12;
monthlyPayment = (iPrincipal * (monthlyIntRate +
((monthlyIntRate) / (((1 + monthlyIntRate)^totNumPayments) - 1))))
;
RETURN monthlyPayment;
END;
$$;
SELECT Miller_24_monthlyPayment(250000.00, 0.04125, 30);


    ------------------------------- finds cust_id and customer_name who have a loan and no account ------------------------------
(SELECT c.cust_ID, c.customer_name
FROM customer AS c INNER JOIN borrower AS b ON c.cust_ID = b.cust_ID
GROUP BY c.cust_ID, c.customer_name
HAVING COUNT(DISTINCT b.loan_number) >= 1)
INTERSECT
(SELECT c.cust_ID, c.customer_name
FROM customer AS c FULL OUTER JOIN depositor AS d ON c.cust_ID = d.cust_ID
GROUP BY c.cust_ID, c.customer_name
HAVING COUNT(DISTINCT d.account_number) = 0);

	------------------------------- finds cust_id and customer_name who live on the same street and city as cust #12345 ------------------------------
SELECT c.cust_ID, customer_name
FROM customer AS c
WHERE c.customer_street LIKE (SELECT customer_street FROM customer WHERE cust_ID = '12345')
AND c.customer_city LIKE (SELECT customer_city FROM customer WHERE cust_ID = '12345');   

	------------------------------- finds branch that has at least one customer who lives in Harrison------------------------------
SELECT b.branch_name
FROM branch AS b
INNER JOIN account AS a ON b.branch_name = a.branch_name
INNER JOIN depositor AS d ON a.account_number = d.account_number
INNER JOIN customer AS c ON d.cust_ID = c.cust_ID
WHERE c.customer_city LIKE 'Harrison'
GROUP BY b.branch_name HAVING COUNT(c.cust_ID) >= 1;

	------------------------------- finds customer name where customer has an account with every bank in Brooklyn ------------------------------
SELECT c.customer_name
FROM customer AS c
INNER JOIN depositor AS d ON c.cust_ID = d.cust_ID
INNER JOIN account AS a ON d.account_number = a.account_number
INNER JOIN branch AS b ON a.branch_name = b.branch_name
WHERE b.branch_city LIKE 'Brooklyn'
GROUP BY c.customer_name
HAVING COUNT(DISTINCT a.branch_name) = (SELECT COUNT(DISTINCT bb.branch_name)
FROM branch AS bb
WHERE bb.branch_city LIKE 'Brooklyn');

/*If an account is deleted, then write a trigger to delete the
dependent tuple(s) from the depositor table for every owner of the deleted account. Note
that there may be jointly-owned bank accounts
*/

CREATE OR REPLACE FUNCTION Miller_24_bankTriggerFunction
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS
$$
BEGIN
DELETE FROM depositor
WHERE depositor.cust_ID IN (SELECT d.cust_ID
FROM depositor AS d
WHERE d.account_number = OLD.account_number)
AND NOT EXISTS (SELECT a.account_number
FROM account AS a
WHERE a.account_number = OLD.account_number);
RETURN OLD;
END;
$$;
  
CREATE TRIGGER Miller_24_bankTrigger
AFTER DELETE ON account
FOR EACH ROW
EXECUTE PROCEDURE Miller_24_bankTriggerFunction();
--------------------------------------------------------------------------------
/*				                  Question 4          		  		          */
--------------------------------------------------------------------------------
CREATE TABLE instructor_course_nums (
ID VARCHAR(10),
name VARCHAR(20),
tot_courses INTEGER
);

CREATE OR REPLACE PROCEDURE Miller_24_insCourseNumsProc(INOUT i_ID VARCHAR(10))
LANGUAGE PLPGSQL
AS
$$
DECLARE
c_count INTEGER = 0;
insName VARCHAR(20) = '';
BEGIN
-- determine total courses - into c_count
SELECT COUNT(t.course_id) INTO c_count
FROM teaches AS t INNER JOIN instructor AS i ON t.ID = i.ID
WHERE t.ID = Miller_24_insCourseNumsProc.i_ID;
  
-- determine instructor name - into insName
SELECT i.name INTO insName
FROM instructor AS i
WHERE i.ID = Miller_24_insCourseNumsProc.i_ID;
  
IF EXISTS (SELECT ID
FROM instructor_course_nums
WHERE ID = Miller_24_insCourseNumsProc.i_ID
) THEN -- update existing record
UPDATE instructor_course_nums
SET tot_courses = c_count
WHERE ID = Miller_24_insCourseNumsProc.i_ID;
ELSE -- insert new tuple
INSERT INTO instructor_course_nums (ID, name, tot_courses)
VALUES (Miller_24_insCourseNumsProc.i_ID, insName, c_count);
END IF;
END;
$$
