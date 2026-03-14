USE SubscriberDB;
GO

-- Create the subscription (push subscription from publisher)
EXEC sp_addsubscription @publication = 'TestPublication',
                        @subscriber = @@SERVERNAME,
                        @destination_db = 'SubscriberDB',
                        @subscription_type = 'push',  -- Push from publisher (or 'pull' for subscriber-initiated)
                        @sync_type = 'automatic';  -- Automatic snapshot initialization

-- Add the push agent (runs on distributor)
USE distribution;
GO

EXEC sp_addpushsubscription_agent @publication = 'TestPublication',
                                  @subscriber = @@SERVERNAME,
                                  @subscriber_db = 'SubscriberDB',
                                  @job_login = NULL,  -- Windows integrated; or specify SQL login
                                  @job_password = NULL,
                                  @subscriber_security_mode = 1,  -- Windows integrated
                                  @frequency_type = 64,  -- Continuous
                                  @frequency_interval = 1,
                                  @frequency_subday = 8,
                                  @frequency_subday_interval = 1;
GO
