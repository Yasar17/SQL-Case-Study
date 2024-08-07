select * from artist;
select * from canvas_size;
select * from image_link;
select * from museum;
select * from museum_hours;
select * from product_size;
select * from subject;
select * from work;




---1. Are there museums without any paintings?

SELECT m.museum_id, m.name
	FROM museum m
	LEFT JOIN work w ON m.museum_id = w.museum_id
	WHERE w.work_id IS NULL;



---2. How many paintings have an asking price of more than their regular price?

select count(work_id) 
	from product_size
		where sale_price > regular_price;



---3) Identify the paintings whose asking price is less than 50% of its regular price

	select * 
		from product_size
		where sale_price < (regular_price/2);
		

---4) Which canva size costs the most?

SELECT cs.size_id,cs.label, ps.sale_price
FROM canvas_size cs
JOIN product_size ps ON cs.size_id::integer = ps.size_id::integer 
WHERE ps.sale_price = (SELECT MAX(sale_price) FROM product_size);



---5) Identify the museums with invalid city information in the given dataset

select * from museum
	where city ~ '[0-9]';


---6) Museum_Hours table has 1 invalid entry. Identify it and remove it.

WITH DuplicateRows AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY museum_id, day ORDER BY (SELECT NULL)) AS rn
    FROM Museum_Hours
)
DELETE FROM Museum_Hours
WHERE (museum_id, day, open, close) IN (
    SELECT museum_id, day, open, close
    FROM DuplicateRows
    WHERE rn > 1
);


---7. Fetch the top 10 most famous painting subject

SELECT s.subject, COUNT(1) AS no_of_paintings
FROM work w
JOIN subject s ON s.work_id = w.work_id
GROUP BY s.subject
ORDER BY no_of_paintings DESC
LIMIT 10;


--8. Identify the museums which are open on both Sunday and Monday. Display museum name, city

SELECT DISTINCT m.name AS museum_name, m.city, m.state, m.country
FROM museum_hours mh
JOIN museum m ON m.museum_id = mh.museum_id
WHERE mh.day = 'Sunday'
AND EXISTS (
    SELECT 1
    FROM museum_hours mh2 
    WHERE mh2.museum_id = mh.museum_id 
    AND mh2.day = 'Monday'
);


---9) How many museums are open every single day?

WITH cte AS (
    SELECT museum_id, COUNT(DISTINCT day) AS count
    FROM museum_hours
    GROUP BY museum_id
)
SELECT COUNT(museum_id) AS museums_open_every_day
FROM cte
WHERE count = 7;


----10. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

SELECT museum.name AS museum_name
FROM museum
INNER JOIN work ON museum.museum_id = work.museum_id
GROUP BY museum.name, museum.museum_id
ORDER BY COUNT(*) DESC
LIMIT 5;

select m.name as museum, m.city,m.country,x.no_of_painintgs
	from (	select m.museum_id, count(1) as no_of_painintgs
			, rank() over(order by count(1) desc) as rnk
			from work w
			join museum m on m.museum_id=w.museum_id
			group by m.museum_id) x
	join museum m on m.museum_id=x.museum_id
	where x.rnk<=5;


---11. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select full_name,work.artist_id,count(work_id) as count
from work
join artist on work.artist_id = artist.artist_id
group by full_name,work.artist_id	
order by count desc
limit 5;


---12. Display the 3 least popular canva sizes

SELECT canvas_size.size_id, COUNT(product_size.size_id) AS popularity_count
FROM canvas_size 
JOIN product_size ON canvas_size.size_id::text = product_size.size_id
GROUP BY canvas_size.size_id 
ORDER BY popularity_count ASC
LIMIT 3;



---13.Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

select museum_name,state as city,day, open, close, duration
	from (	select m.name as museum_name, m.state, day, open, close
			, to_timestamp(open,'HH:MI AM') 
			, to_timestamp(close,'HH:MI PM') 
			, to_timestamp(close,'HH:MI PM') - to_timestamp(open,'HH:MI AM') as duration
			, rank() over (order by (to_timestamp(close,'HH:MI PM') - to_timestamp(open,'HH:MI AM')) desc) as rnk
			from museum_hours mh
		 	join museum m on m.museum_id=mh.museum_id) x
	where x.rnk=1;



----14 Which museum has the most no of most popular painting style?

select m.name,style,count(work_id) as count
from work w
join museum m on w.museum_id = m.museum_id
	group by m.name,style
	order by count desc
	limit 1;


----15 Identify the artists whose paintings are displayed in multiple countries

SELECT a.artist_id, a.full_name AS artist_name, COUNT(DISTINCT m.country) AS country_count
FROM work w
JOIN artist a ON w.artist_id = a.artist_id
JOIN museum m ON w.museum_id = m.museum_id
GROUP BY a.artist_id, a.full_name
HAVING COUNT(DISTINCT m.country) > 1
ORDER BY country_count DESC;


---16. Display the country and the city with most no of museums. Output 2 seperate
--columns to mention the city and country. If there are multiple value, seperate them
--with comma

with cte_country as 
			(select country, count(1)
			, rank() over(order by count(1) desc) as rnk
			from museum
			group by country),
		cte_city as
			(select city, count(1)
			, rank() over(order by count(1) desc) as rnk
			from museum
			group by city)
	select string_agg(distinct country.country,', '), string_agg(city.city,', ')
	from cte_country country
	cross join cte_city city
	where country.rnk = 1
	and city.rnk = 1;



---17. Identify the artist and the museum where the most expensive and least expensive
--painting is placed. Display the artist name, sale_price, painting name, museum
---name, museum city and canvas label

with cte as 
		(select *
		, rank() over(order by sale_price desc) as rnk
		, rank() over(order by sale_price ) as rnk_asc
		from product_size )
	select w.name as painting
	, cte.sale_price
	, a.full_name as artist
	, m.name as museum, m.city
	, cz.label as canvas
	from cte
	join work w on w.work_id=cte.work_id
	join museum m on m.museum_id=w.museum_id
	join artist a on a.artist_id=w.artist_id
	join canvas_size cz on cz.size_id = cte.size_id::NUMERIC
	where rnk=1 or rnk_asc=1;



---18. Which country has the 5th highest no of paintings?
	with cte as 
		(select m.country, count(1) as no_of_Paintings
		, rank() over(order by count(1) desc) as rnk
		from work w
		join museum m on m.museum_id=w.museum_id
		group by m.country)
	select country, no_of_Paintings
	from cte 
	where rnk=5;


---19. Which are the 3 most popular and 3 least popular painting styles?
	with cte as 
		(select style, count(1) as cnt
		, rank() over(order by count(1) desc) rnk
		, count(1) over() as no_of_records
		from work
		where style is not null
		group by style)
	select style
	, case when rnk <=3 then 'Most Popular' else 'Least Popular' end as remarks 
	from cte
	where rnk <=3
	or rnk > no_of_records - 3;



---20. Which artist has the most no of Portraits paintings outside USA?.
--Display artist name, no of paintings and the artist nationality.
	select full_name as artist_name, nationality, no_of_paintings
	from (
		select a.full_name, a.nationality
		,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as rnk
		from work w
		join artist a on a.artist_id=w.artist_id
		join subject s on s.work_id=w.work_id
		join museum m on m.museum_id=w.museum_id
		where s.subject='Portraits'
		and m.country != 'USA'
		group by a.full_name, a.nationality) x
	where rnk=1;	

				






			





















