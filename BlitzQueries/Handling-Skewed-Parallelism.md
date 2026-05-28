# Handling Skewed Parallelism in SQL Server

**Skewed parallelism** (also known as parallel row skew) occurs when SQL Server divides a query's workload among multiple CPU threads, but **one or a few threads do almost all the heavy lifting** while the remaining threads sit idle. This completely negates the performance benefits of a high Max Degree of Parallelism (MAXDOP).

---

## 🔍 How to Detect Skewed Parallelism

You can definitively identify parallel skew by examining the **Actual Execution Plan**. 

### 1. Uneven Rows per Thread
Right-click an operator (such as a `Parallel Clustered Index Seek` or `Hash Match`) and expand the **Actual Number of Rows** property. Check if `Thread 1` has millions of rows while `Thread 2` through `Thread N` have zero or very few rows.

### 2. Disproportionate Wait Statistics
Look out for high `CXPACKET` or `CXCONSUMER` wait times accompanied by a low difference between overall **CPU Time** and **Elapsed Time**. If a query takes 15 seconds of elapsed time and only 16 seconds of CPU time on a `MAXDOP 8` machine, parallelism is failing you.

### 3. TempDB Spills
Because SQL Server calculates memory grants globally and divides them equally across threads, the one heavily-skewed thread only gets a fraction of the required memory. This frequently causes severe **TempDB memory spills** on that specific thread.

---

## 🛠️ Root Causes & Resolution Strategies

### 1. Outdated Statistics or Bad Cardinality Estimates
If the Query Optimizer believes it is dealing with 10 rows when there are actually 10 million, the Parallel Page Supplier will not distribute the threads efficiently.
*   **Resolution**: Update the table statistics with a full scan to give the optimizer accurate distribution histograms.
    ```sql
    UPDATE STATISTICS dbo.YourTable WITH FULLSCAN;
    ```

### 2. Heavily Skewed Underlying Data Distributions
If 90% of your table rows share the exact same foreign key or status value, operators like *Parallel Nested Loops* or *Hash Joins* using a modulo hash function will naturally route all those identical values to the exact same thread.
*   **The `CROSS APPLY / TOP` Trick**: Forcing a serial zone in your plan can re-balance the subsequent parallel stream. By adding a `TOP` clause inside a `CROSS APPLY`, you force SQL Server to process smaller chunks before distributing rows down the pipeline.
*   **The `VALUES` Clause Rewrite**: Instead of doing a standard correlated subquery, pass heavily repeated filter values inside a `VALUES` block, alias them, and join them back. This tricks the optimizer into picking highly efficient Batch Mode processing or standard Hash Joins instead of parallel loops.

### 3. Join Operators & Optimization Hints
Certain join behaviors break parallel balance, particularly when combined with high MAXDOP.
*   **Resolution**: Force a specific distribution mechanism using a query hint. For example, `OPTION (HASH GROUP)` or `OPTION (REPARTITION STREAMS)` can force SQL Server to redistribute the data across threads right before a heavy aggregation or join.

### 4. Non-Parallel Aware Operators
Operators like **Eager Index Spools** are notoriously serial-bound. If one appears in a parallel zone, the immediately preceding index access will bunch up all rows onto a single thread.
*   **Resolution**: Eliminate the need for the spool by creating a supporting index that covers the query's `WHERE` and `JOIN` criteria natively, circumventing the spool entirely.

### 5. Adjust Global Parallelism Guardrails
If the query cannot be rewritten and the parallelism overhead is causing server-wide issues, you must tweak your instance configuration parameters.
*   **Increase Cost Threshold for Parallelism**: The default value of `5` is severely outdated. Raise this to `50` so small queries don't trigger inefficient, skewed parallel plans.
*   **Lower MAXDOP for the Query**: Reducing it to a lower number or forcing it to run serially (`MAXDOP 1`) will eradicate thread sync bottlenecks and prevent memory grant starvation.
    ```sql
    SELECT * FROM dbo.YourTable 
    WHERE SkewedColumn = 'MassiveValue'
    OPTION (MAXDOP 2); -- Or 1 to completely bypass parallel skew
    ```

---

## 📚 Community Resources & Deep Dives

### 📰 Technical Blogs & Articles
*   **Brent Ozar**: Learn how the parallel page supplier fails in [Skewing Parallelism For Fun And Profit](https://www.brentozar.com/archive/2018/10/skewing-parallelism-for-fun-and-profit/).
*   **Erik Darling (Darling Data)**: Read a deep-dive analysis on [A Follow Up On Fixing Parallel Plan Row Skew In SQL Server](https://erikdarling.com/a-follow-up-on-fixing-parallel-plan-row-skew-in-sql-server/).
*   **SQLShack**: Understand the relationship between table layout and engine behavior in [Understanding Skewed Data in SQL Server](https://www.sqlshack.com/understanding-skewed-data-in-sql-server/).

### 📺 Video Tutorials
*   **Fixing Row Skew with TOP**: Watch how a `CROSS APPLY` rewrite drops query times from 15 seconds to 0 seconds in [Fixing Parallel Row Skew With TOP In SQL Server](https://www.youtube.com/watch?v=l8mZheh5-co).
*   **The VALUES Clause Hack**: Learn how to write batch-mode friendly queries to split threads evenly in [A Follow Up On Fixing Parallel Plan Row Skew](https://www.youtube.com/watch?v=pQ4K0P69SAU).
*   **Data Skew vs Parallel Skew**: See a live demonstration of how modulo hash distribution concentrates rows onto a single thread in [A Little About Skewed Data and Skewed Parallelism](https://www.youtube.com/watch?v=8UhkvEwenC8).
