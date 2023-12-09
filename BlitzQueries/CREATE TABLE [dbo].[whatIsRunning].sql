USE [DBA]
GO
/****** Object:  Table [dbo].[whatIsRunning]    Script Date: 3/29/2018 11:42:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[whatIsRunning](
	[session_id] [smallint] NOT NULL,
	[DBName] [nvarchar](128) NULL,
	[percent_complete] [real] NULL,
	[session_status] [nvarchar](30) NOT NULL,
	[request_status] [nvarchar](30) NULL,
	[running_command] [nvarchar](16) NULL,
	[request_wait_type] [nvarchar](60) NULL,
	[request_wait_resource] [nvarchar](256) NULL,
	[request_start_time] [datetime] NULL,
	[request_running_time] [varchar](109) NULL,
	[est_time_to_go] [varchar](109) NULL,
	[est_completion_time] [datetime] NULL,
	[blocked by] [smallint] NULL,
	[statement_text] [nvarchar](max) NULL,
	[Batch_Text] [nvarchar](max) NULL,
	[WaitTime(S)] [numeric](17, 6) NULL,
	[total_elapsed_time(S)] [numeric](17, 6) NULL,
	[login_time] [datetime] NOT NULL,
	[host_name] [nvarchar](128) NULL,
	[host_process_id] [int] NULL,
	[client_interface_name] [nvarchar](32) NULL,
	[login_name] [nvarchar](128) NOT NULL,
	[memory_usage] [int] NOT NULL,
	[session_writes] [bigint] NOT NULL,
	[request_writes] [bigint] NULL,
	[session_logical_reads] [bigint] NOT NULL,
	[request_logical_reads] [bigint] NULL,
	[is_user_process] [bit] NOT NULL,
	[session_row_count] [bigint] NOT NULL,
	[request_row_count] [bigint] NULL,
	[sql_handle] [varbinary](64) NULL,
	[plan_handle] [varbinary](64) NULL,
	[open_transaction_count] [int] NULL,
	[request_cpu_time] [int] NULL,
	[granted_query_memory] [varchar](26) NULL,
	[query_hash] [binary](8) NULL,
	[query_plan_hash] [binary](8) NULL,
	[BatchQueryPlan] [xml] NULL,
	[SqlQueryPlan] [xml] NULL,
	[program_name] [nvarchar](138) NULL,
	[IsSqlJob] [int] NOT NULL,
	[Source] [varchar](100) NULL,
	[CollectionTime] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
