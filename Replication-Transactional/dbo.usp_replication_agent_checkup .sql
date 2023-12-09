use DBA
GO
IF OBJECT_ID('dbo.usp_replication_agent_checkup') IS NULL
	EXECUTE ('create procedure dbo.usp_replication_agent_checkup as select 1 as dummy')
GO

ALTER procedure dbo.usp_replication_agent_checkup  
	@heartbeat_interval int = 10        -- minutes
	,@recepients varchar(2000) = 'ajay.dwivedi@contso.com'
	,@verbose bit = 0
	,@perform_agent_restart bit = 0
as  
	set nocount on;

    declare @distribution_db sysname  
    declare @retstatus int  
    declare @proc nvarchar(255)  
    declare @retcode int  
  
    /*  
    ** Security Check: require sysadmin  
    */  
	if @verbose = 1
		print 'Checking if current executor is Sysadmin';
    IF (ISNULL(IS_SRVROLEMEMBER('sysadmin'),0) = 0)  
    BEGIN  
        RAISERROR(21089,16,-1)   
        RETURN (1)  
    END  
  
    declare hCdistdbs CURSOR LOCAL FAST_FORWARD for  
        select name from msdb..MSdistributiondbs where   
            has_dbaccess(name) = 1  
    for read only  
    open hCdistdbs  
    fetch hCdistdbs into @distribution_db  
    while @@fetch_status <> -1  
    begin  
     select @proc = QUOTENAME(@distribution_db) + '.sys.sp_MSagent_retry_stethoscope' 
		if @verbose = 1
			print 'execute  '+@proc+';';
        execute  @retcode = @proc   
        if @@error <> 0 or @retcode <> 0  
        begin  
            select @retstatus = 1  
            goto UNDO  
        end  
          
        select @proc = QUOTENAME(@distribution_db) + '.sys.sp_MSagent_stethoscope'
		if @verbose = 1
			print 'execute  '+@proc+' '+cast(@heartbeat_interval as varchar(10))+';';
        execute  @retcode = @proc @heartbeat_interval  
        if @@error <> 0 or @retcode <> 0  
        begin  
            select @retstatus = 1  
            goto UNDO  
        end  
        fetch hCdistdbs into @distribution_db  
    end  
  
    set @retstatus = 0  
  
UNDO:  
    close hCdistdbs  
    deallocate hCdistdbs  
    return (@retstatus)  
