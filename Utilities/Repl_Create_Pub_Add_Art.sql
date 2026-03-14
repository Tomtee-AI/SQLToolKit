USE PublisherDB;
GO

-- Create the publication
EXEC sp_addpublication @publication = 'TestPublication',
                       @description = 'Transactional publication for TestTable',
                       @sync_method = 'concurrent',
                       @retention = 0,  -- Unlimited retention (adjust as needed)
                       @allow_push = 'true',
                       @allow_pull = 'true',
                       @independent_agent = 'true';

-- Add snapshot agent security (use SQL auth or Windows; adjust credentials)
EXEC sp_addpublication_snapshot @publication = 'TestPublication',
                                @security_mode = 1;  -- Windows integrated

-- Add articles (tables) to replicate
EXEC sp_addarticle @publication = 'TestPublication',
                   @article = 'TestTable',
                   @source_owner = 'dbo',
                   @source_object = 'TestTable',
                   @type = 'logbased';  -- Transactional with schema
GO
