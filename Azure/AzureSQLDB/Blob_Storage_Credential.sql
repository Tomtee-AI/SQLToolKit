USE master;
GO

-- Replace with your actual values
CREATE CREDENTIAL [https://mystorageaccount.blob.core.windows.net/]
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
     SECRET = 'sv=2023-11-03&ss=b&srt=co&sp=rwdl&se=2027-12-31T23:59:59Z&st=2025-01-01T00:00:00Z&spr=https&sig=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
GO
