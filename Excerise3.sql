CREATE PROCEDURE sp_GetAdvancedOrderDeliveryReport
    @StartDate DATE,
    @EndDate DATE,
    @Country VARCHAR(100) = NULL,
    @City VARCHAR(100) = NULL,
    @VIPOnly BIT = NULL,
    @Category VARCHAR(100) = NULL,
    @RegionName VARCHAR(100) = NULL,
    @StaffID INT = NULL,
    @MinOrderAmount DECIMAL(18, 2) = NULL,
    @MaxOrderAmount DECIMAL(18, 2) = NULL,
    @OrderStatus VARCHAR(50) = NULL,
    @DeliveryStatus VARCHAR(50) = NULL,
    @IncludeDiscounts BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ParamDefinition NVARCHAR(1000);

    SET @ParamDefinition = N'
        @StartDate DATE,
        @EndDate DATE,
        @Country VARCHAR(100),
        @City VARCHAR(100),
        @VIPOnly BIT,
        @Category VARCHAR(100),
        @RegionName VARCHAR(100),
        @StaffID INT,
        @MinOrderAmount DECIMAL(18, 2),
        @MaxOrderAmount DECIMAL(18, 2),
        @OrderStatus VARCHAR(50),
        @DeliveryStatus VARCHAR(50),
        @IncludeDiscounts BIT';

    SET @SQL = N'
    WITH OrderTotals AS (
        SELECT 
            o.OrderID,
            CASE 
                WHEN @IncludeDiscounts = 1 THEN SUM(oi.Quantity * oi.Price * (1 - p.DiscountPercentage/100))
                ELSE SUM(oi.Quantity * oi.Price)
            END AS TotalOrderAmount,
            SUM(oi.Quantity) AS TotalQuantity
        FROM 
            Orders o
            INNER JOIN OrderItems oi ON o.OrderID = oi.OrderID
            INNER JOIN Products p ON oi.ProductID = p.ProductID
        WHERE 
            o.OrderDate BETWEEN @StartDate AND @EndDate
        GROUP BY 
            o.OrderID
    )
    SELECT 
        o.OrderID,
        o.OrderDate,
        c.CustomerName,
        c.Country,
        c.City,
        c.VIPStatus,
        ot.TotalOrderAmount,
        ot.TotalQuantity,
        s.ShipmentDate,
        s.DeliveryStatus,
        o.Status AS OrderStatus,
        ds.StaffName AS DeliveryStaffName,
        r.RegionName
    FROM 
        Orders o
        INNER JOIN Customers c ON o.CustomerID = c.CustomerID
        INNER JOIN OrderTotals ot ON o.OrderID = ot.OrderID
        LEFT JOIN Shipments s ON o.OrderID = s.OrderID
        LEFT JOIN DeliveryStaff ds ON s.ShipmentID = ds.AssignedShipmentID
        LEFT JOIN Regions r ON s.Region = r.RegionID
        LEFT JOIN OrderItems oi ON o.OrderID = oi.OrderID
        LEFT JOIN Products p ON oi.ProductID = p.ProductID
    WHERE 
        o.OrderDate BETWEEN @StartDate AND @EndDate';

    -- Add optional filters
    IF @Country IS NOT NULL
        SET @SQL = @SQL + N' AND c.Country = @Country';
    
    IF @City IS NOT NULL
        SET @SQL = @SQL + N' AND c.City = @City';
    
    IF @VIPOnly = 1
        SET @SQL = @SQL + N' AND c.VIPStatus = 1';
    
    IF @Category IS NOT NULL
        SET @SQL = @SQL + N' AND p.Category = @Category';
    
    IF @RegionName IS NOT NULL
        SET @SQL = @SQL + N' AND r.RegionName = @RegionName';
    
    IF @StaffID IS NOT NULL
        SET @SQL = @SQL + N' AND ds.StaffID = @StaffID';
    
    IF @MinOrderAmount IS NOT NULL
        SET @SQL = @SQL + N' AND ot.TotalOrderAmount >= @MinOrderAmount';
    
    IF @MaxOrderAmount IS NOT NULL
        SET @SQL = @SQL + N' AND ot.TotalOrderAmount <= @MaxOrderAmount';
    
    IF @OrderStatus IS NOT NULL
        SET @SQL = @SQL + N' AND o.Status = @OrderStatus';
    
    IF @DeliveryStatus IS NOT NULL
        SET @SQL = @SQL + N' AND s.DeliveryStatus = @DeliveryStatus';

    -- Add GROUP BY clause to eliminate duplicates due to multiple products in an order
    SET @SQL = @SQL + N'
    GROUP BY 
        o.OrderID,
        o.OrderDate,
        c.CustomerName,
        c.Country,
        c.City,
        c.VIPStatus,
        ot.TotalOrderAmount,
        ot.TotalQuantity,
        s.ShipmentDate,
        s.DeliveryStatus,
        o.Status,
        ds.StaffName,
        r.RegionName
    ORDER BY 
        o.OrderDate DESC, o.OrderID';

    -- Execute the dynamic SQL
    EXEC sp_executesql 
        @SQL,
        @ParamDefinition,
        @StartDate = @StartDate,
        @EndDate = @EndDate,
        @Country = @Country,
        @City = @City,
        @VIPOnly = @VIPOnly,
        @Category = @Category,
        @RegionName = @RegionName,
        @StaffID = @StaffID,
        @MinOrderAmount = @MinOrderAmount,
        @MaxOrderAmount = @MaxOrderAmount,
        @OrderStatus = @OrderStatus,
        @DeliveryStatus = @DeliveryStatus,
        @IncludeDiscounts = @IncludeDiscounts;

END;
