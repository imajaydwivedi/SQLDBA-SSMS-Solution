
:CONNECT SQL2K12-SVR3
SELECT category_no, category_desc
FROM [CreditReporting].[dbo].[category];
GO

:CONNECT SQL2K12-SVR1
INSERT [Credit].[dbo].[category]
(category_desc)
VALUES ('This is a Test');
GO

-- Wait a few seconds
:CONNECT SQL2K12-SVR3
SELECT category_no, category_desc
FROM [CreditReporting].[dbo].[category];
GO