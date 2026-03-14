USE master;
GO

-- Add the publisher database to the distributor
EXEC sp_adddistpublisher @publisher = @@SERVERNAME,
                         @distribution_db = 'distribution',
                         @security_mode = 1;

-- Enable the database for publishing
EXEC sp_replicationdboption @dbname = 'PublisherDB',
                            @optname = 'publish',
                            @value = 'true';
GO
