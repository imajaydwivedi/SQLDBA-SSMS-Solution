USE TSQL2012;

SELECT	shipperid, companyname, phone
FROM	Sales.Shippers;

SELECT *
FROM Sales.Shippers;

SELECT S.shipperid, companyname, phone AS [phone number]
FROM Sales.Shippers AS S;

/* 
exact numeric
	int, tinyint, small, bigint, decimal/numeric
not-exact number
	float, double
character
	char, varchar, nvarchar


char - ascii character
	0-255
nchar - non-ascii character
	chacter value > 255 

declare @counter smallint = 0;
while (@counter <= 255)
begin
	print '@counter => '+cast(@counter as varchar)+char(@counter)
end


char vs nchar
char vs varchar

address char(500)
	address = 'delhi' -- 500 bytes
address varchar(500)
	address = 'delhi!~!' -- 5 bytes

	2 bytes of overhead 

pan card -> char(10) - 'axgpd5819_'
pan card -> varchar(10) - 'abcde1234f'+'!~!' -> varchar(12)

aadhar card (char)
address (char)

