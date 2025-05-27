/*	Below is the list of Trace Flags that could be appropriate in specific scenarios */

Positive
-----------
1118 -> Allocate uniform extents
2371 -> (Pre-2016) Force dynamic update stats thresholds for databases below 130 compatability

Negative
-----------
2861 -> Capture 0 cost plans

Neutral
------------
4199 -> Enable Query Optimizer Fixes
	--
9481 -> Old CE
2312 -> New CE
9204 -> Get loaded stats for query
3604 -> Output stats to msg tab
	--
11064 -> memory balancing for columnstore inserted
9398 -> Disables Adaptive Joins
7412 -> Get live execution plan
272 -> Disables identity pre-allocation to avoid gaps in the values of an identity column in cases where the server restarts
610 -> (Pre-2016) Enables minimal logging for indexed tables



Query Performance
----------------------
8671 -> spend more time compiling plans, ignore "good enough plan found"
2453 -> table variables can trigger recompile when rows are inserted
8649 -> ignore parallelism operator cost when considering Parallel Plan


OPTION (QUERYTRACEON 8671)
