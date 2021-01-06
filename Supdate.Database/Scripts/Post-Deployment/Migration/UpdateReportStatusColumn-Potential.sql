﻿DECLARE @CompanyId INT

DECLARE @ReportsInProgress TABLE (
  Id INT,
  CompanyId INT,
  UniqueId UNIQUEIDENTIFIER,
  Month DATE,
  Status SMALLINT,
  Summary NVARCHAR(MAX),
  ReportGoals INT,
  ReportMetrics INT,
  ReportAreas INT
)


DECLARE companyCursor CURSOR FOR
SELECT DISTINCT r.CompanyId FROM Report r
INNER JOIN ReportEmail re ON r.Id = re.ReportId
WHERE r.IsStatusManual = 0 AND r.StatusId <> 2 AND r.Summary IS NOT NULL AND re.Status = 2

OPEN companyCursor
FETCH NEXT FROM companyCursor INTO @CompanyId

-- start the loop
WHILE (@@FETCH_STATUS = 0)
BEGIN

  DECLARE @AreaCount INT
  DECLARE @MetricCount INT
  DECLARE @GoalCount INT

  -- Count of Areas, goals and metrics
  SELECT @AreaCount = COUNT(*) FROM Area WHERE CompanyId = @CompanyId
  SELECT @GoalCount = COUNT(*) FROM Goal WHERE CompanyId = @CompanyId
  SELECT @MetricCount = COUNT(*) FROM Metric WHERE CompanyId = @CompanyId

  -- Inserts all the reports of this company in to temporary table
  INSERT INTO @ReportsInProgress(Id, CompanyId, UniqueId, [Month], Summary, Status, ReportGoals, ReportMetrics, ReportAreas)
    SELECT Id, @companyId, UniqueId, [Month], Summary, 0, 0, 0, 0
    FROM Report
    WHERE CompanyId = @companyId AND IsStatusManual = 0 AND StatusId <> 2

  -- Count of Report areas, Report goals, and Report metrics
  UPDATE rs SET ReportGoals = RC.Total
  FROM
    @ReportsInProgress rs
  INNER JOIN
  (
    SELECT COUNT(*) Total, ReportId FROM ReportGoal rg
      INNER JOIN Report r ON r.Id = rg.ReportId
      WHERE r.CompanyId = @CompanyId
      GROUP BY ReportId
  )
  AS RC ON RC.ReportId = rs.Id

  UPDATE rs SET ReportMetrics = RC.Total
  FROM
    @ReportsInProgress rs
  INNER JOIN
  (
    SELECT COUNT(*) Total, ReportId FROM ReportMetric rg
      INNER JOIN Report r ON r.Id = rg.ReportId
      WHERE r.CompanyId = @CompanyId
      GROUP BY ReportId
  )
  AS RC ON RC.ReportId = rs.Id

  UPDATE rs SET ReportAreas = RC.Total
  FROM
    @ReportsInProgress rs
  INNER JOIN
  (
    SELECT COUNT(*) Total, ReportId FROM ReportArea rg
      INNER JOIN Report r ON r.Id = rg.ReportId
      WHERE r.CompanyId = @CompanyId
      GROUP BY ReportId
  )
  AS RC ON RC.ReportId = rs.Id

  -- Update report status
  UPDATE rs SET Status = RC.Completed
  FROM
    @ReportsInProgress rs
  INNER JOIN
  (
    SELECT Id,
      CASE
        WHEN @AreaCount = ReportAreas AND
              @MetricCount = ReportMetrics AND
              @GoalCount = ReportGoals AND
              NULLIF(Summary, '') IS NOT NULL
          THEN 2 ELSE 1 END -- 2 corresponds to Completed in the enum
      AS Completed FROM @ReportsInProgress
  )
  AS RC ON RC.Id = rs.Id

  SELECT
    c.Name, rip.*, @GoalCount AS [Total Goals], @MetricCount AS [Metric Goals], @AreaCount AS [Area Count]
  FROM @ReportsInProgress rip
  INNER JOIN Company c ON c.Id = rip.CompanyId
  WHERE Summary IS NOT NULL
    AND rip.Month < '2016-02-01'
  ORDER BY rip.[Month]

  UPDATE r
  SET r.StatusId = 2
  FROM @ReportsInProgress rip
  INNER JOIN Report r ON r.Id = rip.Id
  WHERE --rip.Status = 2
    rip.Summary IS NOT NULL
    AND rip.Month < '2016-02-01'

  DELETE @ReportsInProgress

  FETCH NEXT FROM companyCursor INTO @companyId
END
CLOSE companyCursor
DEALLOCATE companyCursor
