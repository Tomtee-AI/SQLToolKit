-- Create listener (virtual network name + IP + port)
ALTER AVAILABILITY GROUP MyAG 
ADD LISTENER 'AGListener' (
    WITH IP (N'10.0.0.100', N'255.255.255.0'),  -- Static IP/subnet (adjust)
    PORT = 1433
);
GO