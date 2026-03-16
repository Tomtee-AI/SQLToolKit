USE master;
GO

BACKUP CERTIFICATE YourTDECert 
TO FILE = 'C:\Backup\YourTDECert.cer'  -- Path to backup file
WITH PRIVATE KEY (
    FILE = 'C:\Backup\YourTDECert_Key.pvk',  -- Private key backup
    ENCRYPTION BY PASSWORD = 'YourCertBackupPassword123!'  -- Secure password
);
GO
