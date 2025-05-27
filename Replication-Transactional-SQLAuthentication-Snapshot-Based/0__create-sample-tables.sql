USE [DBATools]
GO

/*
	[Demo\SQL2019].[DBA] is getting data from SQLMonitor

	[Experiment,1432].[DBATools] is dummy database.
*/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[file_io_stats]
(
	[collection_time_utc] [datetime2](7) NOT NULL,
	[database_name] [sysname] NOT NULL,
	[database_id] [int] NOT NULL,
	[file_logical_name] [sysname] NOT NULL,
	[file_id] [int] NOT NULL,
	[file_location] [nvarchar](260) NOT NULL,
	[sample_ms] [bigint] NOT NULL,
	[num_of_reads] [bigint] NOT NULL,
	[num_of_bytes_read] [bigint] NOT NULL,
	[io_stall_read_ms] [bigint] NOT NULL,
	[io_stall_queued_read_ms] [bigint] NOT NULL,
	[num_of_writes] [bigint] NOT NULL,
	[num_of_bytes_written] [bigint] NOT NULL,
	[io_stall_write_ms] [bigint] NOT NULL,
	[io_stall_queued_write_ms] [bigint] NOT NULL,
	[io_stall] [bigint] NOT NULL,
	[size_on_disk_bytes] [bigint] NOT NULL,
	[io_pending_count] [bigint] NULL,
	[io_pending_ms_ticks_total] [bigint] NULL,
	[io_pending_ms_ticks_avg] [bigint] NULL,
	[io_pending_ms_ticks_max] [bigint] NULL,
	[io_pending_ms_ticks_min] [bigint] NULL,
 CONSTRAINT [pk_file_io_stats] PRIMARY KEY CLUSTERED 
(
	[collection_time_utc] ASC,
	[database_id] ASC,
	[file_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

alter table [dbo].[file_io_stats]
	add id bigint identity(1,1) not null
go


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[sql_agent_job_stats]
(
	[JobName] [varchar](255) NOT NULL,
	[Instance_Id] [bigint] NULL,
	[Last_RunTime] [datetime2](7) NULL,
	[Last_Run_Duration_Seconds] [int] NULL,
	[Last_Run_Outcome] [varchar](50) NULL,
	[Last_Successful_ExecutionTime] [datetime2](7) NULL,
	[Running_Since] [datetime2](7) NULL,
	[Running_StepName] [varchar](250) NULL,
	[Running_Since_Min] [bigint] NULL,
	[Session_Id] [int] NULL,
	[Blocking_Session_Id] [int] NULL,
	[Next_RunTime] [datetime2](7) NULL,
	[Total_Executions] [bigint] NULL,
	[Total_Success_Count] [bigint] NULL,
	[Total_Stopped_Count] [bigint] NULL,
	[Total_Failed_Count] [bigint] NULL,
	[Continous_Failures] [int] NULL,
	[<10-Min] [bigint] NOT NULL,
	[10-Min] [bigint] NOT NULL,
	[30-Min] [bigint] NOT NULL,
	[1-Hrs] [bigint] NOT NULL,
	[2-Hrs] [bigint] NOT NULL,
	[3-Hrs] [bigint] NOT NULL,
	[6-Hrs] [bigint] NOT NULL,
	[9-Hrs] [bigint] NOT NULL,
	[12-Hrs] [bigint] NOT NULL,
	[18-Hrs] [bigint] NOT NULL,
	[24-Hrs] [bigint] NOT NULL,
	[36-Hrs] [bigint] NOT NULL,
	[48-Hrs] [bigint] NOT NULL,
	[CollectionTimeUTC] [datetime2](7) NULL,
	[UpdatedDateUTC] [datetime2](7) NOT NULL,
 CONSTRAINT [pk_sql_agent_job_stats] PRIMARY KEY CLUSTERED 
(
	[JobName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

alter table [dbo].[sql_agent_job_stats]
	add id bigint identity(1,1) not null
go



SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[wait_stats]
(
	[collection_time_utc] [datetime2](7) NOT NULL,
	[wait_type] [nvarchar](60) NOT NULL,
	[waiting_tasks_count] [bigint] NOT NULL,
	[wait_time_ms] [bigint] NOT NULL,
	[max_wait_time_ms] [bigint] NOT NULL,
	[signal_wait_time_ms] [bigint] NOT NULL,
 CONSTRAINT [pk_wait_stats] PRIMARY KEY CLUSTERED 
(
	[collection_time_utc] ASC,
	[wait_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

alter table [dbo].[wait_stats]
	add id bigint identity(1,1) not null
go

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[xevent_metrics]
(
	[row_id] [bigint] NOT NULL,
	[start_time] [datetime2](7) NOT NULL,
	[event_time] [datetime2](7) NOT NULL,
	[event_name] [nvarchar](60) NOT NULL,
	[session_id] [int] NOT NULL,
	[request_id] [int] NOT NULL,
	[result] [varchar](50) NULL,
	[database_name] [varchar](255) NULL,
	[client_app_name] [varchar](255) NULL,
	[username] [varchar](255) NULL,
	[cpu_time_ms] [bigint] NULL,
	[duration_seconds] [bigint] NULL,
	[logical_reads] [bigint] NULL,
	[physical_reads] [bigint] NULL,
	[row_count] [bigint] NULL,
	[writes] [bigint] NULL,
	[spills] [bigint] NULL,
	[client_hostname] [varchar](255) NULL,
	[session_resource_pool_id] [int] NULL,
	[session_resource_group_id] [int] NULL,
	[scheduler_id] [int] NULL,
 CONSTRAINT [pk_xevent_metrics] PRIMARY KEY CLUSTERED 
(
	[event_time] ASC,
	[start_time] ASC,
	[row_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

alter table [dbo].[xevent_metrics]
	add id bigint identity(1,1) not null
go



SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[xevent_metrics_queries]
(
	[row_id] [bigint] NOT NULL,
	[start_time] [datetime2](7) NOT NULL,
	[event_time] [datetime2](7) NOT NULL,
	[sql_text] [varchar](max) NULL,
 CONSTRAINT [pk_xevent_metrics_queries] PRIMARY KEY CLUSTERED 
(
	[event_time] ASC,
	[start_time] ASC,
	[row_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

alter table [dbo].[xevent_metrics_queries]
	add id bigint identity(1,1) not null
go

