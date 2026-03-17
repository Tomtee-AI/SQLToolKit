-- Full
BACKUP DATABASE YourDatabaseName 
TO URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Full_20250317.bak'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     FORMAT, 
     STATS = 10,
     COMPRESSION;
GO

--Diff
BACKUP DATABASE YourDatabaseName 
TO URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Diff_20250317.bak'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     DIFFERENTIAL,
     FORMAT,
     STATS = 10,
     COMPRESSION;
GO

--Log
BACKUP LOG YourDatabaseName 
TO URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Log_20250317.trn'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     FORMAT,
     STATS = 10,
     COMPRESSION;
GO
