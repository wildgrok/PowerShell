<#
version in \\CCLDEVSHRDDB1\e$\POWERSHELL
last modified:
#1/17/2020: many changes related to servers_live_today population
12/11/2019: changed $SQL_Reload_EnvironmentsAndApplications
11/12/2019
Added ALL_SERVICES table truncate 
10/23/2019
added sid column to $SQL_GetLogins
9/18/2019: full test with workflow files
Master_App_List_CodeBlocks_WorkFlow.ps1, Master_App_List_CodeBlocks2_WorkFlow.ps1, Master_App_List_version4_WorkFlow.ps1
9/9/2019: added [sys].configurations check
#>

$SQL_Reload_EnvironmentsAndApplications = 
@"
	INSERT INTO [Master_Application_List].[dbo].[Environments And Applications]
	(
	[Application_Name]
	      ,[Application Owner]
		  ,[Application_Tech]
	      ,[Environment]
	      ,[Server]
	      ,[Database]
	      ,[ShoreSide_Shipboard]
	      ,[SqlVersion]
	      ,[Online_Offline]
   )   
	SELECT distinct
	a.[Application_Name]
	,a.[Application Owner]
	,a.[Application_Tech]
	,a.[Environment]
	,a.[Server]
	,a.[Database]
	,a.[ShoreSide_Shipboard]
	,a.[SqlVersion]	 
	,a.[Online_Offline]
	FROM [Master_Application_List].[dbo].[Environments And Applications BACKUP] a
	join [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] b on
		a.[Server] like (b.Machine + '%') and
		b.[Status] is null 	
	order by a.[Environment] ,a.[Server]
"@

$SQL_GetSQLServers_ALL = 'select SqlServer from [Master_Application_List].[dbo].[VW_SQLSERVERS] order by SqlServer'

#NOTE: server_live_today must be populated before this call
$SQL_GetSQLServers_Live = @"
select a.SqlServer from [Master_Application_List].[dbo].[VW_SQLSERVERS]  a
join [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] b on	
	a.[SQLserver] like (b.Machine + '%') and
	b.[Status] is null 
order by SqlServer
"@

# this brings servers before the ping check
$SQL_GetServers    = 'select Machine from [Master_Application_List].[dbo].[VW_SERVERS] order by Machine'

# this brings servers AFTER the ping check
$SQL_GetServers_Live = "SELECT [Machine] FROM [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] where status is null"

$SQL_Get_DBSFromServer = 'set nocount on select name, state_desc as Online_Offline, @@version as SqlVersion from sys.databases where database_id > 4 order by name'
$SQL_GetMissingFrom_ServersAndDatabases = 
@"
SET NOCOUNT ON
INSERT INTO [Master_Application_List].[dbo].[Environments And Applications]
           ([Application_Name]
           ,[Application Owner]
		   ,[Application_Tech]
           ,[Environment]
           ,[Server]
           ,[Database]
           ,[ShoreSide_Shipboard]
           ,[SqlVersion]
           ,[Online_Offline]
)
SELECT 
b.[Application_Name]
,b.[Application Owner]
,b.[Application_Tech]
,b.[Environment]
,replace(a.[SQLServer], char(34), '') as 'SqlServer'
,a.[Database_Name]
,b.[ShoreSide_Shipboard]
,a.[SqlVersion]	 
,a.[Online_Offline]
  FROM [Master_Application_List].[dbo].[Environments And Applications] b  
  RIGHT JOIN  [Master_Application_List].[dbo].[Servers and Databases] a on 
  a.SQLServer = b.[Server] AND
  a.Database_Name = b.[Database]
  where b.[Server] is null and 
  b.[Database] is null
"@

$SQL_FixVersionsAndOnlineOffline = 
@"
SET NOCOUNT ON
UPDATE u
   SET 
      u.[SqlVersion] = s.sqlversion
	  from [Master_Application_List].[dbo].[Environments And Applications] u
 JOIN [Master_Application_List].[dbo].[Servers and Databases] s on
	u.[Server] = s.[SqlServer]

	
UPDATE u
   SET 
      u.[Online_Offline] = s.[Online_Offline]
	  from [Master_Application_List].[dbo].[Environments And Applications] u
 JOIN [Master_Application_List].[dbo].[Servers and Databases] s on
	u.[Server] = s.[SqlServer]  and
	u.[Database] = s.Database_Name		
"@

#Enabled 9/1/2016
$SQL_UpdateFrom_EnvironmentsAndApplicationsBACKUP = 
@"
SET NOCOUNT ON
UPDATE u
   SET u.[Application_Name] = s.[Application_Name]
      ,u.[Application Owner] = s.[Application Owner]
	  ,u.[Application_Tech] = s.[Application_Tech] 
      ,u.[Environment] = s.[Environment]
      --,u.[Server] = s.[Server]
      --,u.[Database] = <Database, varchar(100),>
      ,u.[ShoreSide_Shipboard] = s.[ShoreSide_Shipboard]
      --,u.[SqlVersion] = s.[SqlVersion] 
      --,u.[Online_Offline] = s.[Online_Offline] 
      --,u.[LastUpdated] = <LastUpdated, datetime,>

FROM [Master_Application_List].[dbo].[Environments And Applications] u
RIGHT JOIN [Master_Application_List].[dbo].[Environments And Applications BACKUP] s on
	u.[Server] = s.[Server] AND
	u.[Database] = s.[Database]
"@

# added 8/24/2017
#CHANGED 10/23/2019 added sid column
$SQL_GetLogins =
@"
select name, dbname, sysadmin, isntgroup, isntuser,cast(sid as bigint) as 'sid' 
from master.dbo.syslogins where left(name, 2) <> '##' 
order by name, dbname
"@

# added 8/25/2017
$SQL_GetUsers = 
@"
set nocount on
DECLARE @name sysname,
@sql nvarchar(4000),
@maxlen1 smallint,
@maxlen2 smallint,
@maxlen3 smallint

IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '#tmpTable%')
DROP TABLE #tmpTable

CREATE TABLE #tmpTable 
(
DBName sysname NOT NULL ,
UserName sysname NOT NULL,
RoleName sysname NOT NULL
)

DECLARE c1 CURSOR for 
SELECT name FROM master.sys.databases where state_desc = 'ONLINE'

OPEN c1
FETCH c1 INTO @name
WHILE @@FETCH_STATUS >= 0
BEGIN
SELECT @sql = 
'INSERT INTO #tmpTable
SELECT N'''+ @name + ''', a.name, c.name
FROM [' + @name + '].sys.database_principals a 
JOIN [' + @name + '].sys.database_role_members b ON b.member_principal_id = a.principal_id
JOIN [' + @name + '].sys.database_principals c ON c.principal_id = b.role_principal_id
WHERE a.name != ''dbo'''
EXECUTE (@sql)
FETCH c1 INTO @name
END
CLOSE c1
DEALLOCATE c1

SELECT @maxlen1 = (MAX(LEN(COALESCE(DBName, 'NULL'))) + 2)
FROM #tmpTable

SELECT @maxlen2 = (MAX(LEN(COALESCE(UserName, 'NULL'))) + 2)
FROM #tmpTable

SELECT @maxlen3 = (MAX(LEN(COALESCE(RoleName, 'NULL'))) + 2)
FROM #tmpTable

SET @sql = 'SELECT LEFT(DBName, ' + LTRIM(STR(@maxlen1)) + ') AS ''DBName'', '
SET @sql = @sql + 'LEFT(UserName, ' + LTRIM(STR(@maxlen2)) + ') AS ''UserName'', '
SET @sql = @sql + 'LEFT(RoleName, ' + LTRIM(STR(@maxlen3)) + ') AS ''RoleName'' '
SET @sql = @sql + 'FROM #tmpTable '
SET @sql = @sql + 'WHERE Left(UserName, 2) <> ''##'' '
SET @sql = @sql + 'ORDER BY DBName, UserName'
EXEC(@sql)
"@


$SQL_GetBackupInfo = 
@"
SET NOCOUNT ON
create table #temptemp
(
	db varchar(100), 
	bkdate datetime
)
insert into #temptemp
SELECT 
   msdb.dbo.backupset.database_name, 
   MAX(msdb.dbo.backupset.backup_finish_date) AS last_db_backup_date
 FROM   msdb.dbo.backupmediafamily 
   INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id 
WHERE  msdb..backupset.type = 'D'
GROUP BY
   msdb.dbo.backupset.database_name 
ORDER BY 
   last_db_backup_date desc

select 
rtrim(db) as 'db', 
bkdate from #temptemp 
where bkdate < getdate() - 1 
order by db
"@

$SQL_InsertIntoBackupHistory = 
@"
SET NOCOUNT ON
INSERT INTO [Master_Application_List].[dbo].[Missing Backups History]
(
	[SqlServer]
    ,[DBname]
    ,[BKDate]
)
select * FROM [Master_Application_List].[dbo].[Missing Backups]
delete from [Master_Application_List].[dbo].[Missing Backups History]
where rundate < (getdate() - 30)
"@

$SQL_Insert_Production_Values = 
@"
INSERT INTO [Master_Application_List].[dbo].[Environments And Applications]
(
	[Application_Name]
   ,[Application Owner]
   ,[Application_Tech]
   ,[Environment]
   ,[Server]
   ,[Database]
   ,[ShoreSide_Shipboard]
   ,[SqlVersion]
   ,[Online_Offline]		   
)
	SELECT distinct
     [Application_Name]
     ,[Application Owner]
     ,[Application_Tech]
     ,[Environment]
     ,[Server]
	 ,[Database] 
	 ,[ShoreSide_Shipboard]
     ,[SqlVersion]
     ,[Online_Offline]
	FROM [Master_Application_List].[dbo].[Environments And Applications BACKUP]
	WHERE [Server] like '%PRD%'
"@

$SQL_Servers_And_Databases_Compatibility_Differences_Query = 
@"
set nocount on
select
cast(serverproperty('productversion') as varchar(100))	 as 'server_level', 
name, compatibility_level
into #tmp
from sys.databases
select 
cast(server_level as varchar(100)) as server_level,
cast([name] as varchar(100)) as dbname,
compatibility_level,
case  when cast(left(server_level, 2) as int) <> cast(left(compatibility_level, 2) as int) then '' else 'OK' end AS 'diff' 
from #tmp
drop table #tmp
"@


$SQL_Get_Database_Files_Query = 
@"
SELECT DB_NAME(database_id) AS DatabaseName, name AS LogicalFileName, 
physical_name AS PhysicalFileName, 
case file_id 
	when 2 then 'Log'
	when 1 then 'Data'
	else 'Other' 
end as 'Type',
size
FROM sys.master_files
"@

$SQL_LIST_AG_IPS = 
@"
SET NOCOUNT ON
select l.dns_name, l.port, ip.ip_address, ip_subnet_mask, ip.state_desc, "Data_Center" =   
      CASE   
        WHEN ip.ip_address LIKE '10.224.%' THEN 'DCE    - Miami'
        WHEN ip.ip_address LIKE '172.25%' THEN 'DCE (NON - PROD) - Miami' 
	    WHEN ip.ip_address LIKE '10.244.%' THEN 'PEAK10 - Invalid' 
	    WHEN ip.ip_address LIKE '10.56.%'  THEN 'DCC    - Dallas' 
        ELSE 'UNKNOWN LOCATION - Invalid' 
      END  
from sys.availability_group_listener_ip_addresses ip  
join sys.availability_group_listeners l on l.listener_id = ip.listener_id
"@

$SQL_Serverlist_AG = "SELECT distinct [Listener Name] + ',' + cast([Port] as varchar(10)) as 'Server' FROM [Master_Application_List].[dbo].[AG SQL Servers]"

$SQL_sys_configurations = 
@"
SET NOCOUNT ON
SELECT [name], value  
FROM [sys].configurations 
WHERE [name] in 
(
'Remote access',               -- Should be 0
'cross db ownership chaining', -- Should be 0
'Scan for startup procs',      -- Should be 0
'clr enabled',                 -- Should be 0
'Default trace enabled',       -- Should be 1
'Remote admin connections',    -- Should be 0
'Database Mail XPs',           -- Should be 0
'Ole Automation Procedures',   -- Should be 0
'Xp_cmdshell',                 -- Should be 0
'Ad Hoc Distributed Queries'   -- Should be 0
)
order by [name]
"@

$SQL_Truncate_SQL_Tables = 
@"
SET NOCOUNT ON
truncate table [Master_Application_List].[dbo].[Sys_Configurations];
truncate table [Master_Application_List].[dbo].[Database Files];
truncate table [Master_Application_List].[dbo].[All Logins];
truncate table [Master_Application_List].[dbo].[All Users];
truncate table [Master_Application_List].[dbo].[Servers and Databases];
truncate table [Master_Application_List].[dbo].[Missing Backups];
truncate table [Master_Application_List].[dbo].[Environments And Applications]
"@

$SQL_Truncate_Server_Tables = 
@"
SET NOCOUNT ON
truncate table [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY];
truncate table [Master_Application_List].[dbo].[Machines];
truncate table [Master_Application_List].[dbo].[ALL_SERVICES];
"@