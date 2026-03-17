EXEC sys.sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;

DECLARE @token nvarchar(4000) = 'YourSASWithoutQuestionMark';
EXECUTE sp_OACreate 'Microsoft.WindowsAzure.Storage.Blob.CloudBlobClient', ...;  -- complex, better use Azure CLI/PowerShell
