http://adventuresinsql.com/2009/12/a-busyaccidental-dbas-guide-to-managing-vlfs/
https://www.sqlskills.com/blogs/paul/important-change-vlf-creation-algorithm-sql-server-2014/
https://www.sqlskills.com/blogs/kimberly/transaction-log-vlfs-too-many-or-too-few/

Up to 2014, the algorithm for how many VLFs you get when you create, grow, or auto-grow the log is based on the size in question:

Less than 1 MB, complicated, ignore this case.
Up to 64 MB: 4 new VLFs, each roughly 1/4 the size of the growth
64 MB to 1 GB: 8 new VLFs, each roughly 1/8 the size of the growth
More than 1 GB: 16 new VLFs, each roughly 1/16 the size of the growth

So if you created your log at 1 GB and it auto-grew in chunks of 512 MB to 200 GB, you’d have 8 + ((200 – 1) x 2 x 8) = 3192 VLFs. (8 VLFs from the initial creation, then 200 – 1 = 199 GB of growth at 512 MB per auto-grow = 398 auto-growths, each producing 8 VLFs.)

Why Manage VLFs?
1) Slows database backup/recovery
2) Slows Replication/Logshipping
3) Slow Transactions in some cases

My Preference:-
-------------
Small Size DBs (<50 gb)
	less than 200 vlfs
	Initial Size = 1/2 of current size
	Auto Growth = 500 MB (8 VLFs with each growth)
	
	So, for a db of 20 gb log file with intial size of 10 gb and auto growth of 500 mb, 
		VLF counts would be = (16) + ( (10 * 1024 / 500) * 8 ) = 180
-----------------------------------
Medium Size DBs (>50 & <200)
	Less than 500 vlfs
	Initial Size = 1/3 of current size
	Auto Growth = 4 gb (16 VLFs with each growth)
	
	So, for a db of 200 gb log file with intial size of 166 gb and auto growth of 500 mb, 
		VLF counts would be = (16) + ( (134 / 4) * 16 ) = 552
-----------------------------------
Large Size DBs (> 200 gb)
	Less than 8000 vlfs
	Initial Size = 1/2 of current size
	Auto Growth = 8 gb (16 VLFs with each growth)
	
	So, for a db of 8000 gb log file with intial size of 166 gb and auto growth of 500 mb, 
		VLF counts would be = (16) + ( (400 / 8) * 16 ) = 816
-----------------------------------


