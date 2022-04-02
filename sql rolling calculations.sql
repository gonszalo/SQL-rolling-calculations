use sakila;

-- first i'll create a view with all the data i'm going to need:

create or replace view sakila.customer_activity as
select customer_id, convert(date, date) as Activity_date,
rental_date(convert(date, date), '%m') as Activity_Month,
rental_date(convert(date,date), '%Y') as Activity_year
from sakila.rental;

select * from sakila.customer_list;

-- getting the total number of active user per month and year

create or replace view sakila.monthly_active_customers as
select Activity_year, Activity_Month, count(distinct account_id) as Active_customers
from sakila.customers_activity
group by Activity_year, Activity_Month
order by Activity_year asc, Activity_Month asc;

-- using LAG() to get the users from previous month

select 
   Activity_year, 
   Activity_month,
   Active_users, 
   lag(Active_customers) over () as Last_month -- order by Activity_year, Activity_Month -- lag(Active_users, 2) -- partition by Activity_year
from monthly_active_customers;

select 
   Activity_year, 
   Activity_month,
   Active_users, 
   lag(Active_users) over () as Last_month -- order by Activity_year, Activity_Month -- lag(Active_users, 2) -- partition by Activity_year
from monthly_active_customers;


create or replace view bank.diff_monthly_active_customers as
with cte_view as 
(
	select 
	Activity_year, 
	Activity_month,
	Active_users, 
	lag(Active_users) over (order by Activity_year, Activity_Month) as Last_month
	from monthly_active_customers
)
select 
   Activity_year, 
   Activity_month, 
   Active_users, 
   Last_month, 
   (Active_customers - Last_month) as Difference 
from cte_view;

select * from diff_monthly_active_customers;


-- Rolling Calculations with Self Joins

-- step 1: get the unique active users per month
create or replace view sakila.distinct_customers as
select
	distinct 
	customer_id as Active_id, 
	Activity_year, 
	Activity_month
from sakila.user_activity
order by Activity_year, Activity_month, account_id;

select * from sakila.distinct_users;


-- step 2: self join to find recurrent customers (users that made a transfer this month and also last month)
create or replace view sakila.recurrent_customers as
select d1.Active_id, d1.Activity_year, d1.Activity_month from sakila.distinct_users d1
join sakila.distinct_users d2
on d1.Activity_year = d2.Activity_year -- case when m1.Activity_month = 1 then m1.Activity_year + 1 else m1.Activity_year end
and d1.Activity_month = d2.Activity_month+1 -- case when m2.Activity_month+1 = 13 then 12 else m2.Activity_month+1 end;
and d1.Active_id = d2.Active_id -- to get recurrent users
order by d1.Active_id, d1.Activity_year, d1.Activity_month;

select * from sakila.recurrent_customers;

-- step 3: count recurrent customers per month 
create or replace view sakila.total_recurrent_customers as
select Activity_year, Activity_month, count(Active_id) as Recurrent_customers from recurrent_customers
group by Activity_year, Activity_month;

-- step 4: use lag to have this month and previous month side by side
create or replace view sakila.recurrent_customers_monthly as
select *,
lag(Recurrent_customers) over () as Previous_month_customers
from sakila.total_recurrent_customers;

-- step 5: get the difference between recurrent users from this month and previous month
select *, Recurrent_customers - Previous_month_customers from recurrent_customers_monthly





-- Percentage change in the number of active customers

with customer_activity as
(
-- in the cte we get last months active users with lag()
  select
    Activity_year, Activity_month, Active_users,
    lag(Active_users,1) over (partition by Activity_year) as last_month
  from monthly_active_users
)
select
  activity_year, activity_month,
-- then we subtract this months users with last months and calculate the percentage
  (Active_users-last_month)/Active_users*100 as percentage_change
from cte_activity
where last_month is not null;
