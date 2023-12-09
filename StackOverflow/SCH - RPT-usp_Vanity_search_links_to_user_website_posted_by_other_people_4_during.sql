use StackOverflow
go

create or alter procedure dbo.usp_Vanity_search_links_to_user_website_posted_by_other_people_4_during @UserId int, @StartDate date, @EndDate date
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/1181/vanity-search-links-to-my-website-posted-by-other-people-during-last-2-months
	-- Vanity search: links to my website posted by other people during last 2 months

	WITH    mylink AS
			(
			SELECT  id, REPLACE(WebsiteUrl, 'http://', '') AS site
			FROM    users
			WHERE   id = @UserId
			),
			mylink2 AS
			(
			SELECT  id, CASE SUBSTRING(site, LEN(site), 1) WHEN '/' THEN SUBSTRING(site, 0, LEN(site)) ELSE site END AS se
			FROM    mylink
			)
	SELECT  p.id AS [Post Link], p.LastActivityDate AS [Last Activity]
	FROM    (
			SELECT  p.id
			FROM    mylink2 ml
			JOIN    posts p
			ON      p.body LIKE '%' + se + '%' ESCAPE '!'
					AND p.OwnerUserId <> ml.id
			WHERE   (p.LastActivityDate between @StartDate and @EndDate)
					AND se <> ''
					AND se IS NOT NULL
			UNION
			SELECT  c.PostId
			FROM    mylink2 ml
			JOIN    comments c
			ON      c.text LIKE '%' + se + '%' ESCAPE '!'
					AND c.UserId <> ml.id
			WHERE   (c.CreationDate between @StartDate and @EndDate)
					AND se <> ''
					AND se IS NOT NULL
			) q
	JOIN    posts p
	ON      p.id = q.id
	ORDER BY
			p.LastActivityDate DESC
end
go

exec dbo.usp_Vanity_search_links_to_user_website_posted_by_other_people_4_during @UserId = 26837, @StartDate = '2015-01-01', @EndDate = '2020-05-01'
go
