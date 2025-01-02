-- Get Distribution Agent history
  -- Execute on [DistributorServer]
use [<DistributionDbNameHere>];
SELECT  h.agent_id, a.name AS agent_name, h.start_time, h.time, h.duration, h.comments, 
		h.delivery_rate, h.delivered_commands, h.average_commands, h.error_id
FROM   MSdistribution_history h
JOIN   MSdistribution_agents a ON h.agent_id = a.id
WHERE  1=1
and a.publication = '<PublicationNameHere>'
and (case when h.comments like '<stats%' then 0
			else 1
			end) = 1
AND h.time >= DATEADD(HOUR, -4, GETDATE()) -- Past 4 hours
AND a.subscriber_id > 0 -- Ensures it's a subscriber agent
ORDER BY  h.time DESC;
go

-- Insert a Tracer Token
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>];
DECLARE @tokenID INT;
EXEC sp_posttracertoken
		@publication = '<PublicationNameHere>'
		,@tracer_token_id = @tokenID OUTPUT;
SELECT @tokenID AS TokenID;
go


-- Get Tracer Token Status
  -- Execute on [DistributorServer]
use [<DistributionDbNameHere>];
select t.tracer_id, t.publisher_commit, t.distributor_commit, h.subscriber_commit
from dbo.MSpublications pl
left join dbo.MStracer_tokens t on pl.publication_id = t.publication_id
left join dbo.MStracer_history h on h.parent_tracer_id = t.tracer_id
where 1=1
and pl.publication = '<PublicationNameHere>';
go

