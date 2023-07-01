

/* Trigger to update Payment status if payment status is confirmed*/
 
DELIMITER $
CREATE TRIGGER Update_Order_status
AFTER update ON Order_detail
FOR EACH ROW
BEGIN
    IF NEW.Payment_status = 'Paid' THEN
        UPDATE Order_detail SET Order_status = 'Confirmed' WHERE Order_id = NEW.Order_id;
	elseif
		NEW.Payment_status = 'Unpaid' THEN
        UPDATE Order_detail SET Order_status = 'InProgress' WHERE Order_id = NEW.Order_id;
    END IF;
END $$
DELIMITER ;

drop trigger Update_Order_status;


 
 /*
 1.The CEO of ‘Small Bazar’ wants to check the profitability of the Branches.
 Create a View for his use which will show monthly Profit of all Branches for the current year.
 */
                    
CREATE or REPLACE VIEW Monthly_Profit AS 
SELECT b.Branch_id, MONTH(Order_date) as month, SUM(selling_price - cost_price)*Order_quantity as profit_in_Rs from Branch as b join Branch_product 
using (Branch_id)
JOIN Orders ON Branch_product.Branch_id = Orders.Branch_id
WHERE YEAR(Order_date) = YEAR(CURRENT_DATE())
GROUP BY Branch_id, MONTH(Order_date);

select * from Monthly_Profit;


/*
2.Create a stored procedure having countryName, FromDate and ToDate as Parameter, which will return Sitewise,
 Item Wise and Date Wise the number of items sold in the given Date range as separate resultsets. 
 Create appropriate Indexes on the tables.
*/

DELIMITER //
Create procedure all_in_one(countryName varchar(20),FromDate date,ToDate date)
BEGIN

-- site wise
SELECT b.Branch_country,b.Branch_location, sum(od.Order_quantity) as Total_sale 
FROM  Branch as b 
join orders as o
using(Branch_id) 
join
Order_detail as od using (Order_id) 
where 
b.Branch_country = countryName
and
Order_date between FromDate and ToDate
group by b.Branch_location;


-- Product wise
SELECT p.Product_name, sum(od.Order_quantity) as Total_sale 
FROM  Product as p 
join order_detail as od
using(Product_id) 
join Orders using(Order_id)
where
Order_date between FromDate and ToDate
group by p.Product_name;

-- Date wise
SELECT o.Order_date , sum(od.Order_quantity) as Total_sale 
FROM  Product as p 
join order_detail as od
using(Product_id) 
join Orders as o  using(Order_id)
where
Order_date between FromDate and ToDate
group by o.Order_date ;

END //

DELIMITER ;

select * from branch;
drop procedure all_in_one;
call all_in_one('USA','2022-02-02','2024-12-01');



/*
3. Create a stored procedure which will calculate the total bill for any order. Bill should have details like: 
CustomerName, 
orderId,
 OrderDate,
 Branch,
 ProductName, 
 Price per Unit,

 No. Of Units,
 Total Cost of that product,
 Total Bill Amount,
 Additional Charges (0 if none),
 Delivery Option (‘Home Delivery' or ‘self-Pickup’).
*/
DELIMITER //
CREATE PROCEDURE Bill(IN ordersid int)
BEGIN
SELECT c.Customer_name, o.Order_id,b.Branch_id,p.Product_name,bp.Selling_price as Price_per_unit,
od.Order_quantity,(bp.selling_price*od.Order_quantity) as Total_bill_amount,
case when o.Order_type = "Home Delivery" then '50Rs'
ELSE '0Rs'  
END AS  'Additional_charge' ,
Order_type
FROM  Customer AS c 
JOIN Orders AS o  USING (Customer_id)
JOIN Branch as b USING (Branch_id)
JOIN Branch_product AS bp USING (Branch_id) 
JOIN Product AS p USING (Product_id)
JOIN Order_detail AS od USING(Product_id)
where o.order_id = ordersid ;
END//

DROP PROCEDURE Bill;

CALL Bill(23);

select * from order_detail;

/*
4. Create a (function) Procedure having a parameter as
country name, which displays all the branches available in the country that are active. 
*/

DELIMITER //
CREATE  PROCEDURE show_status(CountryName varchar(30))
BEGIN

select Branch_id,Branch_name,Branch_status
FROM
Branch b 
where Branch_status = 'active' and  b.Branch_country = CountryName;
END//

DROP PROCEDURE show_status;
CALL show_status('USA');
 
 /*
 5.The CEO of ‘Small Bazar’ wants to check the profitability of the Branches. 
 Create a stored procedure that shows the branch profit if profit is below a certain threshold flag that branch as below par performance.
*/
 
 DELIMITER //
 CREATE PROCEDURE Sinking_Branches(set_benchmark int) 
 BEGIN
 SELECT b.Branch_name, b.Branch_country,SUM(bp.selling_price - bp.cost_price)*Order_quantity as Profit, 
 CASE WHEN
			SUM(bp.selling_price - bp.cost_price)*Order_quantity  <= set_benchmark
 THEN 'Non Profitable Branch'
 ELSE 'Profitable Branch'
 END AS profitability
 FROM Branch_product AS bp
 JOIN
 Branch AS b USING (Branch_id)
 JOIN
 Orders AS o USING(Branch_id)
 JOIN
 Order_detail AS od USING(Order_id)
 GROUP BY Branch_id;
 END //
 DROP PROCEDURE Sinking_Branches;
 CALL Sinking_Branches(5820);
 
/*
6.find out country where people are using least plastic bag while they are shopping.
*/

CREATE or replace VIEW Bag_count AS
SELECT b.Branch_country,count(od.Bag_id) as PlasticBagsUsed FROM Branch as b
JOIN 
Orders as o USING(Branch_id)
JOIN
Order_detail AS od using(Order_id)
WHERE od.Bag_id 
= 1  group by b.Branch_country order by PlasticBagsUsed asc
LIMIT 1;                  
 
 select * from Bag_count;
 
 
 /*
 7. Many business owners focus only on customer acquisition, but customer retention can also drive loyalty,
 word of mouth marketing, and higher order values. But CEO want to know if when a customer shops if he is new customer or old customer,
 if old customer keep count of that customer visited small bazar regardless or branch, city, country
If customer shops more than 10 times 
Give me privilege customer category 
*/

DELIMITER //
CREATE PROCEDURE track_customer()
BEGIN
DECLARE Customer_count int default 0;
DECLARE Customer_category VARCHAR(20);
SELECT COUNT(DISTINCT Customer_id) INTO Customer_count
FROM orders;

IF Customer_count > 10 THEN
SET  Customer_category = 'Privilege';
ELSE 
SET Customer_category = 'Regular';
END IF;
SELECT Customer_category as 'customer category', Customer_count as 'Number of Visits'
FROM Orders;
END//

DROP PROCEDURE track_customer;
call track_customer;

/*
Optional
Write a Trigger which will reduce the stock of some product whenever an order is confirmed by the number of that product in the order.
 E.g. If an order with 10 Oranges is confirmed from Nagpur branch, Stock of Oranges from Nagpur branch must be reduced by 10.

*/
DELIMITER $$
CREATE TRIGGER Update_stock
AFTER INSERT ON Order_detail
FOR EACH ROW
BEGIN
	declare B_id int default 0;
    select O.Branch_id form  into b_id from Orders as o
    join Order_detail using (Order_id)
    where o.Order_id = new.Order_id;
    
    update Branch_product  set 
    Product_quantity = Product_quantity - new.Order_quantity
    WHERE Product_id=NEW.Product_id and Branch_id = Branch_id;
END $$
 
SELECT * FROM Branch_product;
 drop trigger Update_stock;