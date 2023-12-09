# BlitzQueries - Project

### 1) What's Running

<b> [Latest Code of WhatIsRunning Script](WhatIsRunning.sql)</b>

I have created this TSQL Query that provide almost all information regarding running queries. This code gives query at Batch Level and at individual TSQL query within that Batch. Incase the running session is SQL Agent job, then <b>[Program_Name]</b> column data would be shown like 'SQL Job = &lt; job name &gt;'.
Below is sample screenshot.

![](WhatIsRunning.gif)

### 2) Adam Mechanic's [sp_WhoIsActive] - Modified

<b> [Latest Code of Modified [sp_WhoIsActive] Script](who_is_active_v11_30(Modified).sql)</b>

I am big fan of [Adam Mechanic's [sp_WhoIsActive]](http://whoisactive.com/downloads/). I have modified the latest script `v11.30` to provide the `job name` in case the running session belongs to sql agent job. Below are sample screenshots.

![](sp_whoIsActive.gif)
