USE [DBA]
GO

CREATE TABLE [dbo].[WhoIsActive_ResultSets]
(
	[dd hh:mm:ss.mss] [varchar](8000) NULL,
	[dd hh:mm:ss.mss (avg)] [varchar](15) NULL,
	[session_id] [smallint] NOT NULL,
	[sql_text] [xml] NULL,
	[sql_command] [xml] NULL,
	[login_name] [nvarchar](128) NOT NULL,
	[wait_info] [nvarchar](4000) NULL,
	[tasks] [varchar](30) NULL,
	[tran_log_writes] [nvarchar](4000) NULL,
	[CPU] [varchar](30) NULL,
	[tempdb_allocations] [varchar](30) NULL,
	[tempdb_current] [varchar](30) NULL,
	[blocking_session_id] [smallint] NULL,
	[blocked_session_count] [varchar](30) NULL,
	[reads] [varchar](30) NULL,
	[writes] [varchar](30) NULL,
	[context_switches] [varchar](30) NULL,
	[physical_io] [varchar](30) NULL,
	[physical_reads] [varchar](30) NULL,
	[locks] [xml] NULL,
	[used_memory] [varchar](30) NULL,
	[status] [varchar](30) NOT NULL,
	[tran_start_time] [datetime] NULL,
	[open_tran_count] [varchar](30) NULL,
	[percent_complete] [varchar](30) NULL,
	[host_name] [nvarchar](128) NULL,
	[database_name] [nvarchar](128) NULL,
	[program_name] [nvarchar](128) NULL,
	[additional_info] [xml] NULL,
	[start_time] [datetime] NOT NULL,
	[login_time] [datetime] NULL,
	[request_id] [int] NULL,
	[collection_time] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO



