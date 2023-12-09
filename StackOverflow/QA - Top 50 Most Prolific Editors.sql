-- https://data.stackexchange.com/stackoverflow/query/6627/top-50-most-prolific-editors
/* Shows the top 50 post editors, where the user was the most recent editor (meaning the results are conservative compared to the actual number of edits).
*/

-- Top 50 Most Prolific Editors
-- Shows the top 50 post editors, where the user was the most recent editor
-- (meaning the results are conservative compared to the actual number of edits).

SELECT TOP 50 /* Top 50 Most Prolific Editors */
    Id AS [User Link],
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            PostTypeId = 1 AND
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS QuestionEdits,
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            PostTypeId = 2 AND
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS AnswerEdits,
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS TotalEdits
    FROM Users
    ORDER BY TotalEdits DESC