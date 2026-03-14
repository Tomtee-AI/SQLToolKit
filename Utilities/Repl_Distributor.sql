-- Enable distribution on the instance
USE master;
GO

EXEC sp_adddistributor @distributor = @@SERVERNAME;  -- Use current server as distributor

-- Create the distribution database
EXEC sp_adddistributiondb @database = 'distribution';
GO

-- Set up the distributor properties (adjust paths as needed)
EXEC sp_adddistpublisher @publisher = @@SERVERNAME,
                         @distribution_db = 'distribution',
                         @security_mode = 1;  -- Windows integrated security

GO
