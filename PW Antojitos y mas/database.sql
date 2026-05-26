/* ================================================================
   SABOR DE LA VIDA — Base de Datos SQL Server
   Archivo: database.sql
   Motor:   Microsoft SQL Server 2019+
   Autor:   Generado para proyecto universitario

   CONTENIDO DEL SCRIPT:
     1. Creación de la base de datos y configuración
     2. Creación de tablas (esquema relacional)
     3. Restricciones, índices y claves foráneas
     4. Datos iniciales (INSERT semilla)
     5. Stored Procedures (alta automática de pedidos)
     6. Trigger de auditoría (registro automático de cambios)
     7. Vistas de consulta frecuente
     8. Jobs / Tareas programadas para reportes automáticos
   ================================================================ */


/* ================================================================
   SECCIÓN 1: CREACIÓN DE LA BASE DE DATOS
   ================================================================ */

USE master;
GO

-- Eliminar si ya existe (desarrollo/testing)
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'SaborDelaVida')
BEGIN
    ALTER DATABASE SaborDelaVida SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SaborDelaVida;
END
GO

-- Crear la base de datos
CREATE DATABASE SaborDelaVida
    ON PRIMARY (
        NAME        = N'SaborDelaVida_Data',
        FILENAME    = N'C:\SQLData\SaborDelaVida.mdf',
        SIZE        = 64MB,
        FILEGROWTH  = 32MB
    )
    LOG ON (
        NAME        = N'SaborDelaVida_Log',
        FILENAME    = N'C:\SQLData\SaborDelaVida.ldf',
        SIZE        = 16MB,
        FILEGROWTH  = 8MB
    );
GO

USE SaborDelaVida;
GO

-- Configuración de lenguaje y zona horaria
SET LANGUAGE Spanish;
GO


/* ================================================================
   SECCIÓN 2: CREACIÓN DE TABLAS
   Descripción: Esquema relacional del sistema del restaurante.

   Jerarquía:
     Categorias
       └── Productos
     Clientes
       └── Pedidos
             └── DetallePedido → Productos
     Empleados
     MetodosPago
     Auditoría (automática por trigger)
   ================================================================ */


-- ----------------------------------------------------------------
-- TABLA: Categorias
-- Descripción: Categorías del menú (Platos Fuertes, Antojitos, etc.)
-- ----------------------------------------------------------------
CREATE TABLE Categorias (
    CategoriaID   INT           NOT NULL IDENTITY(1,1),
    Nombre        NVARCHAR(60)  NOT NULL,
    Descripcion   NVARCHAR(200) NULL,
    Orden         TINYINT       NOT NULL DEFAULT 0,   -- Para ordenar en el menú
    Activo        BIT           NOT NULL DEFAULT 1,
    FechaCreacion DATETIME2     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_Categorias PRIMARY KEY (CategoriaID),
    CONSTRAINT UQ_Categorias_Nombre UNIQUE (Nombre),
    CONSTRAINT CHK_Categorias_Orden CHECK (Orden BETWEEN 0 AND 99)
);
GO


-- ----------------------------------------------------------------
-- TABLA: Productos
-- Descripción: Todos los items del menú con precio y disponibilidad
-- ----------------------------------------------------------------
CREATE TABLE Productos (
    ProductoID    INT             NOT NULL IDENTITY(1,1),
    CategoriaID   INT             NOT NULL,
    Nombre        NVARCHAR(100)   NOT NULL,
    Descripcion   NVARCHAR(300)   NULL,
    Precio        DECIMAL(10,2)   NOT NULL,
    ImagenURL     NVARCHAR(500)   NULL,
    Disponible    BIT             NOT NULL DEFAULT 1,
    EsDestacado   BIT             NOT NULL DEFAULT 0,  -- Para "featured" en la web
    FechaCreacion DATETIME2       NOT NULL DEFAULT GETDATE(),
    FechaModif    DATETIME2       NULL,

    CONSTRAINT PK_Productos PRIMARY KEY (ProductoID),
    CONSTRAINT FK_Productos_Categorias FOREIGN KEY (CategoriaID)
        REFERENCES Categorias (CategoriaID)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT CHK_Productos_Precio CHECK (Precio > 0)
);
GO

-- Índice para búsquedas por categoría (consultas frecuentes)
CREATE INDEX IX_Productos_CategoriaID ON Productos (CategoriaID);
CREATE INDEX IX_Productos_Disponible  ON Productos (Disponible);
GO


-- ----------------------------------------------------------------
-- TABLA: Clientes
-- Descripción: Clientes del restaurante. Los pedidos WhatsApp
--              pueden ser anónimos (nombre requerido, teléfono opcional)
-- ----------------------------------------------------------------
CREATE TABLE Clientes (
    ClienteID     INT           NOT NULL IDENTITY(1,1),
    Nombre        NVARCHAR(100) NOT NULL,
    Telefono      NVARCHAR(20)  NULL,
    Correo        NVARCHAR(150) NULL,
    Direccion     NVARCHAR(250) NULL,
    FechaRegistro DATETIME2     NOT NULL DEFAULT GETDATE(),
    Activo        BIT           NOT NULL DEFAULT 1,

    CONSTRAINT PK_Clientes PRIMARY KEY (ClienteID),
    CONSTRAINT UQ_Clientes_Telefono UNIQUE (Telefono),
    CONSTRAINT CHK_Clientes_Correo CHECK (
        Correo IS NULL OR Correo LIKE '%@%.%'
    )
);
GO

CREATE INDEX IX_Clientes_Telefono ON Clientes (Telefono);
GO


-- ----------------------------------------------------------------
-- TABLA: MetodosPago
-- Descripción: Catálogo de métodos de pago aceptados
-- ----------------------------------------------------------------
CREATE TABLE MetodosPago (
    MetodoPagoID  INT          NOT NULL IDENTITY(1,1),
    Descripcion   NVARCHAR(60) NOT NULL,
    Activo        BIT          NOT NULL DEFAULT 1,

    CONSTRAINT PK_MetodosPago PRIMARY KEY (MetodoPagoID),
    CONSTRAINT UQ_MetodosPago_Desc UNIQUE (Descripcion)
);
GO


-- ----------------------------------------------------------------
-- TABLA: Empleados
-- Descripción: Personal del restaurante (meseros, cocina, admin)
-- ----------------------------------------------------------------
CREATE TABLE Empleados (
    EmpleadoID    INT           NOT NULL IDENTITY(1,1),
    Nombre        NVARCHAR(100) NOT NULL,
    Cargo         NVARCHAR(60)  NOT NULL,  -- 'Mesero', 'Cocinero', 'Cajero', 'Admin'
    Telefono      NVARCHAR(20)  NULL,
    FechaIngreso  DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Activo        BIT           NOT NULL DEFAULT 1,

    CONSTRAINT PK_Empleados PRIMARY KEY (EmpleadoID),
    CONSTRAINT CHK_Empleados_Cargo CHECK (
        Cargo IN ('Mesero', 'Cocinero', 'Cajero', 'Administrador', 'Bartender')
    )
);
GO


-- ----------------------------------------------------------------
-- TABLA: Pedidos
-- Descripción: Cabecera de cada pedido. Puede ser presencial
--              (mesa) o remoto (WhatsApp / Domicilio).
-- ----------------------------------------------------------------
CREATE TABLE Pedidos (
    PedidoID      INT            NOT NULL IDENTITY(1,1),
    ClienteID     INT            NULL,    -- NULL = cliente ocasional sin registro
    EmpleadoID    INT            NULL,    -- Mesero/cajero que tomó el pedido
    MetodoPagoID  INT            NULL,
    NumeroMesa    TINYINT        NULL,    -- NULL si es para llevar/domicilio
    TipoPedido    NVARCHAR(20)   NOT NULL DEFAULT 'Presencial',
    Estado        NVARCHAR(20)   NOT NULL DEFAULT 'Recibido',
    Subtotal      DECIMAL(10,2)  NOT NULL DEFAULT 0,
    Descuento     DECIMAL(10,2)  NOT NULL DEFAULT 0,
    Total         DECIMAL(10,2)  NOT NULL DEFAULT 0,
    Notas         NVARCHAR(500)  NULL,
    FechaPedido   DATETIME2      NOT NULL DEFAULT GETDATE(),
    FechaEntrega  DATETIME2      NULL,

    CONSTRAINT PK_Pedidos PRIMARY KEY (PedidoID),
    CONSTRAINT FK_Pedidos_Clientes FOREIGN KEY (ClienteID)
        REFERENCES Clientes (ClienteID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT FK_Pedidos_Empleados FOREIGN KEY (EmpleadoID)
        REFERENCES Empleados (EmpleadoID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT FK_Pedidos_MetodosPago FOREIGN KEY (MetodoPagoID)
        REFERENCES MetodosPago (MetodoPagoID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT CHK_Pedidos_TipoPedido CHECK (
        TipoPedido IN ('Presencial', 'WhatsApp', 'Domicilio', 'Para llevar')
    ),
    CONSTRAINT CHK_Pedidos_Estado CHECK (
        Estado IN ('Recibido', 'En preparación', 'Listo', 'Entregado', 'Cancelado')
    ),
    CONSTRAINT CHK_Pedidos_Totales CHECK (Total >= 0 AND Subtotal >= 0 AND Descuento >= 0)
);
GO

-- Índices para reportes por fecha y estado
CREATE INDEX IX_Pedidos_FechaPedido  ON Pedidos (FechaPedido);
CREATE INDEX IX_Pedidos_Estado       ON Pedidos (Estado);
CREATE INDEX IX_Pedidos_ClienteID    ON Pedidos (ClienteID);
GO


-- ----------------------------------------------------------------
-- TABLA: DetallePedido
-- Descripción: Items de cada pedido. Precio unitario se copia del
--              catálogo para preservar el histórico si cambia.
-- ----------------------------------------------------------------
CREATE TABLE DetallePedido (
    DetalleID       INT           NOT NULL IDENTITY(1,1),
    PedidoID        INT           NOT NULL,
    ProductoID      INT           NOT NULL,
    Cantidad        TINYINT       NOT NULL DEFAULT 1,
    PrecioUnitario  DECIMAL(10,2) NOT NULL,  -- Precio snapshot al momento del pedido
    Subtotal        AS (Cantidad * PrecioUnitario) PERSISTED,  -- Columna calculada
    Notas           NVARCHAR(200) NULL,       -- Instrucciones especiales del ítem

    CONSTRAINT PK_DetallePedido PRIMARY KEY (DetalleID),
    CONSTRAINT FK_Detalle_Pedidos FOREIGN KEY (PedidoID)
        REFERENCES Pedidos (PedidoID)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT FK_Detalle_Productos FOREIGN KEY (ProductoID)
        REFERENCES Productos (ProductoID)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT CHK_Detalle_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CHK_Detalle_Precio   CHECK (PrecioUnitario > 0)
);
GO

CREATE INDEX IX_DetallePedido_PedidoID   ON DetallePedido (PedidoID);
CREATE INDEX IX_DetallePedido_ProductoID ON DetallePedido (ProductoID);
GO


-- ----------------------------------------------------------------
-- TABLA: Auditoria
-- Descripción: Registro automático de cambios en pedidos.
--              Poblado por el trigger TR_Pedidos_Auditoria.
-- ----------------------------------------------------------------
CREATE TABLE Auditoria (
    AuditoriaID   INT            NOT NULL IDENTITY(1,1),
    Tabla         NVARCHAR(60)   NOT NULL,
    Operacion     CHAR(6)        NOT NULL,   -- INSERT, UPDATE, DELETE
    RegistroID    INT            NOT NULL,
    UsuarioSQL    NVARCHAR(128)  NOT NULL DEFAULT SYSTEM_USER,
    FechaHora     DATETIME2      NOT NULL DEFAULT GETDATE(),
    DatosAntes    NVARCHAR(MAX)  NULL,       -- JSON del estado anterior
    DatosDespues  NVARCHAR(MAX)  NULL,       -- JSON del estado nuevo

    CONSTRAINT PK_Auditoria PRIMARY KEY (AuditoriaID),
    CONSTRAINT CHK_Auditoria_Op CHECK (Operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO


/* ================================================================
   SECCIÓN 3: DATOS INICIALES (SEED DATA)
   Descripción: Poblar las tablas de catálogo con los datos del menú
                extraídos de las imágenes del restaurante.
   ================================================================ */


-- ---- Categorías ----
INSERT INTO Categorias (Nombre, Descripcion, Orden) VALUES
    ('Platos Fuertes', 'Especialidades de res, cerdo y pollo',           1),
    ('Antojitos',      'Tradición nicaragüense: alitas, nachos, tajadas', 2),
    ('Ceviches',       'Del mar a tu mesa. Frescos y preparados al momento', 3),
    ('Bebidas',        'Bar y coctelería. Cervezas, cócteles y licores',  4),
    ('Extras',         'Complementa tu pedido: aderezos y acompañamientos', 5);
GO


-- ---- Métodos de pago ----
INSERT INTO MetodosPago (Descripcion) VALUES
    ('Efectivo'),
    ('Tarjeta de crédito'),
    ('Tarjeta de débito'),
    ('Transferencia bancaria'),
    ('WhatsApp Pay');
GO


-- ---- Empleados de ejemplo ----
INSERT INTO Empleados (Nombre, Cargo, Telefono, FechaIngreso) VALUES
    ('María López',    'Administrador', '8888-0001', '2023-01-15'),
    ('Carlos Ramos',   'Mesero',        '8888-0002', '2023-03-01'),
    ('Ana Martínez',   'Cocinero',      '8888-0003', '2023-03-01'),
    ('Luis Herrera',   'Bartender',     '8888-0004', '2023-05-10'),
    ('Sofía García',   'Cajero',        '8888-0005', '2024-01-20');
GO


-- ---- Productos: Platos Fuertes (CategoriaID = 1) ----
INSERT INTO Productos (CategoriaID, Nombre, Descripcion, Precio, EsDestacado) VALUES
    (1, 'Cerdo - Choleta Ahomada',
        'Choleta de cerdo ahomada al carbón con guarnición',
        300.00, 0),
    (1, 'Res - Chorrasco',
        'Chorrasco a la parrilla con papas y ensalada',
        450.00, 1),
    (1, 'Res - Fajitas',
        'Fajitas de res con chile morrón, cebolla y tortillas',
        450.00, 0),
    (1, 'Res - Filete Jalapeño',
        'Filete de res con salsa de jalapeño',
        450.00, 0),
    (1, 'Res - Brochetas',
        'Brochetas de res con vegetales a la parrilla',
        450.00, 0),
    (1, 'Pollo - Alitas',
        'Alitas de pollo en salsa BBQ o búfalo',
        320.00, 0),
    (1, 'Pollo - Fajitas',
        'Fajitas de pollo con chile morrón y cebolla',
        320.00, 0),
    (1, 'Pollo - Filete Jalapeño',
        'Filete de pollo con salsa de jalapeño',
        320.00, 0),
    (1, 'Pollo - Brochetas',
        'Brochetas de pollo con vegetales',
        320.00, 0);
GO


-- ---- Productos: Antojitos (CategoriaID = 2) ----
INSERT INTO Productos (CategoriaID, Nombre, Descripcion, Precio, EsDestacado) VALUES
    (2, 'Surtido Familiar Sabor de la Vida',
        'Para 4 personas. Pollo, res, cerdo, chorizos, queso, maduro, papas, tajadas, gallopinto y encurtido',
        1200.00, 1),
    (2, 'Alitas con Papas',
        'Alitas fritas con papas y aderezo de la casa',
        350.00, 0),
    (2, 'Tajadas con Carne',
        'Tajadas verdes fritas con carne molida',
        220.00, 0),
    (2, 'Nachos Especiales',
        'Nachos con jalapeños, guacamole y queso derretido',
        250.00, 0);
GO


-- ---- Productos: Ceviches (CategoriaID = 3) ----
INSERT INTO Productos (CategoriaID, Nombre, Descripcion, Precio) VALUES
    (3, 'Ceviche de Camarón',
        'Camarón fresco marinado en limón y chile, con galletas o tajadas',
        350.00),
    (3, 'Cóctel de Camarón',
        'Camarón en salsa especial de la casa',
        350.00),
    (3, 'Ceviche Mixto',
        'Camarón, pulpo y pescado marinados. Ingredientes frescos del día',
        400.00),
    (3, 'Ceviche de Pescado',
        'Pescado fresco del día marinado en limón',
        300.00),
    (3, 'Cóctel de Pulpo',
        'Pulpo fresco con verduras y salsa especial',
        420.00),
    (3, 'Cóctel de Langosta',
        'Langosta fresca en salsa especial de la casa',
        350.00);
GO


-- ---- Productos: Bebidas (CategoriaID = 4) ----
INSERT INTO Productos (CategoriaID, Nombre, Descripcion, Precio) VALUES
    (4, 'Toña - Botella',        'Cerveza nacional nicaragüense',              45.00),
    (4, 'Heineken - Botella',    'Cerveza internacional importada',             82.00),
    (4, 'Sol - Botella',         'Cerveza internacional mexicana',              75.00),
    (4, 'Lite - Botella',        'Cerveza internacional light',                 60.00),
    (4, 'Cubetazo Toña',         '6 Toñas en cubeta de hielo',                240.00),
    (4, 'Cóctel de la Casa',     'Preparación especial del bartender',         120.00),
    (4, 'Ron Flor de Caña',      'Copa de ron nicaragüense 5 o 7 años',        90.00),
    (4, 'Agua Mineral',          'Botella de agua mineral 600ml',              25.00);
GO


-- ---- Productos: Extras (CategoriaID = 5) ----
INSERT INTO Productos (CategoriaID, Nombre, Descripcion, Precio) VALUES
    (5, 'Papas Western',              'Papas estilo western crujientes',        70.00),
    (5, 'Papas Francesas',            'Papas fritas clásicas',                  50.00),
    (5, 'Tostones / Tajadas / Queso', 'Porción de tostones, tajadas o queso',  40.00),
    (5, 'Fuente de Hielo',            'Cubeta de hielo para bebidas',           40.00),
    (5, 'Aderezo Ranch',              'Porción de aderezo ranch',               30.00),
    (5, 'Aderezo Búfalo',             'Porción de salsa búfalo',                30.00),
    (5, 'Aderezo BBQ',                'Porción de salsa BBQ',                   35.00),
    (5, 'Queso Cheddar',              'Porción de queso cheddar derretido',     40.00),
    (5, 'Mostaza Miel',               'Porción de mostaza con miel',            30.00),
    (5, 'Chile Criollo',              'Porción de chile criollo nicaragüense',  35.00);
GO


-- ---- Clientes de ejemplo ----
INSERT INTO Clientes (Nombre, Telefono, Correo) VALUES
    ('Cliente General',  NULL,           NULL),
    ('Pedro Castillo',   '8765-4321',    'pedro@correo.com'),
    ('Laura Jiménez',    '8123-5678',    'laura@correo.com');
GO


/* ================================================================
   SECCIÓN 4: STORED PROCEDURES
   Descripción: Procedimientos almacenados para operaciones comunes.
                Permiten que los registros se realicen de forma
                automática desde la aplicación web.
   ================================================================ */


-- ----------------------------------------------------------------
-- SP: usp_CrearPedido
-- Descripción: Crea un pedido completo con sus detalles en una
--              sola transacción atómica. Calcula totales automáticamente.
-- Parámetros:
--   @ClienteID    — ID del cliente (NULL si es anónimo)
--   @EmpleadoID   — ID del mesero/cajero
--   @TipoPedido   — 'Presencial', 'WhatsApp', 'Domicilio', etc.
--   @NumeroMesa   — Número de mesa (NULL si no aplica)
--   @Notas        — Notas generales del pedido
--   @DetallesXML  — XML con los items: <items><item id="1" cant="2"/></items>
-- Retorna: PedidoID creado
-- ----------------------------------------------------------------
CREATE OR ALTER PROCEDURE usp_CrearPedido
    @ClienteID    INT           = NULL,
    @EmpleadoID   INT           = NULL,
    @TipoPedido   NVARCHAR(20)  = 'Presencial',
    @NumeroMesa   TINYINT       = NULL,
    @Notas        NVARCHAR(500) = NULL,
    @DetallesXML  XML           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Variables locales
    DECLARE @PedidoID   INT;
    DECLARE @Subtotal   DECIMAL(10,2) = 0;
    DECLARE @Total      DECIMAL(10,2) = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertar cabecera del pedido
        INSERT INTO Pedidos (ClienteID, EmpleadoID, TipoPedido, NumeroMesa, Notas, Estado)
        VALUES (@ClienteID, @EmpleadoID, @TipoPedido, @NumeroMesa, @Notas, 'Recibido');

        SET @PedidoID = SCOPE_IDENTITY();

        -- 2. Si se enviaron detalles en XML, insertarlos
        IF @DetallesXML IS NOT NULL
        BEGIN
            -- Parsear XML e insertar DetallePedido
            INSERT INTO DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario)
            SELECT
                @PedidoID,
                x.ProductoID,
                x.Cantidad,
                p.Precio   -- Copiar precio actual del catálogo
            FROM (
                SELECT
                    t.c.value('@id',   'INT')     AS ProductoID,
                    t.c.value('@cant', 'TINYINT') AS Cantidad
                FROM @DetallesXML.nodes('/items/item') AS t(c)
            ) AS x
            INNER JOIN Productos p ON p.ProductoID = x.ProductoID
            WHERE p.Disponible = 1;

            -- 3. Calcular subtotal sumando los detalles insertados
            SELECT @Subtotal = SUM(Subtotal)
            FROM DetallePedido
            WHERE PedidoID = @PedidoID;

            -- 4. Actualizar totales en la cabecera
            UPDATE Pedidos
            SET Subtotal = @Subtotal,
                Total    = @Subtotal  -- Sin descuento inicial
            WHERE PedidoID = @PedidoID;
        END

        COMMIT TRANSACTION;

        -- Retornar el ID del pedido creado
        SELECT @PedidoID AS PedidoID, @Subtotal AS Subtotal;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO


-- ----------------------------------------------------------------
-- SP: usp_ActualizarEstadoPedido
-- Descripción: Cambia el estado de un pedido y registra la
--              hora de entrega si el estado es 'Entregado'.
-- ----------------------------------------------------------------
CREATE OR ALTER PROCEDURE usp_ActualizarEstadoPedido
    @PedidoID  INT,
    @NuevoEstado NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF @NuevoEstado NOT IN ('Recibido','En preparación','Listo','Entregado','Cancelado')
    BEGIN
        RAISERROR('Estado inválido. Use: Recibido, En preparación, Listo, Entregado, Cancelado', 16, 1);
        RETURN;
    END

    UPDATE Pedidos
    SET Estado       = @NuevoEstado,
        FechaEntrega = CASE WHEN @NuevoEstado = 'Entregado' THEN GETDATE() ELSE FechaEntrega END
    WHERE PedidoID   = @PedidoID;

    IF @@ROWCOUNT = 0
        RAISERROR('PedidoID no encontrado.', 16, 1);

    SELECT PedidoID, Estado, FechaEntrega FROM Pedidos WHERE PedidoID = @PedidoID;
END
GO


-- ----------------------------------------------------------------
-- SP: usp_ObtenerResumenVentas
-- Descripción: Reporte de ventas por día o rango de fechas.
--              Devuelve totales por categoría de producto.
-- ----------------------------------------------------------------
CREATE OR ALTER PROCEDURE usp_ObtenerResumenVentas
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Por defecto: hoy
    IF @FechaInicio IS NULL SET @FechaInicio = CAST(GETDATE() AS DATE);
    IF @FechaFin    IS NULL SET @FechaFin    = @FechaInicio;

    SELECT
        c.Nombre                              AS Categoria,
        COUNT(DISTINCT d.PedidoID)            AS TotalPedidos,
        SUM(d.Cantidad)                       AS UnidadesVendidas,
        SUM(d.Subtotal)                       AS TotalVentas,
        CAST(AVG(d.PrecioUnitario) AS DECIMAL(10,2)) AS PrecioPromedio
    FROM DetallePedido d
    INNER JOIN Pedidos   p ON p.PedidoID   = d.PedidoID
    INNER JOIN Productos pr ON pr.ProductoID = d.ProductoID
    INNER JOIN Categorias c ON c.CategoriaID = pr.CategoriaID
    WHERE
        CAST(p.FechaPedido AS DATE) BETWEEN @FechaInicio AND @FechaFin
        AND p.Estado <> 'Cancelado'
    GROUP BY c.Nombre
    ORDER BY TotalVentas DESC;
END
GO


-- ----------------------------------------------------------------
-- SP: usp_RegistrarClienteWhatsApp
-- Descripción: Registra o actualiza un cliente que llega desde
--              WhatsApp. Si el teléfono ya existe, devuelve el ID.
-- ----------------------------------------------------------------
CREATE OR ALTER PROCEDURE usp_RegistrarClienteWhatsApp
    @Nombre   NVARCHAR(100),
    @Telefono NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClienteID INT;

    -- Buscar si ya existe el teléfono
    SELECT @ClienteID = ClienteID
    FROM Clientes
    WHERE Telefono = @Telefono;

    IF @ClienteID IS NULL
    BEGIN
        -- Insertar nuevo cliente
        INSERT INTO Clientes (Nombre, Telefono)
        VALUES (@Nombre, @Telefono);

        SET @ClienteID = SCOPE_IDENTITY();
    END

    SELECT @ClienteID AS ClienteID;
END
GO


/* ================================================================
   SECCIÓN 5: TRIGGER DE AUDITORÍA
   Descripción: Se activa automáticamente en cada INSERT, UPDATE
                o DELETE en la tabla Pedidos. Registra el cambio
                en la tabla Auditoria con datos JSON del antes/después.
   ================================================================ */

CREATE OR ALTER TRIGGER TR_Pedidos_Auditoria
ON Pedidos
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Determinar la operación realizada
    DECLARE @Operacion CHAR(6);

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Operacion = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Operacion = 'INSERT';
    ELSE
        SET @Operacion = 'DELETE';

    -- Para INSERT y UPDATE: registrar el estado nuevo
    IF @Operacion IN ('INSERT', 'UPDATE')
    BEGIN
        INSERT INTO Auditoria (Tabla, Operacion, RegistroID, DatosDespues)
        SELECT
            'Pedidos',
            @Operacion,
            i.PedidoID,
            (
                SELECT
                    i.PedidoID,
                    i.ClienteID,
                    i.Estado,
                    i.Total,
                    i.TipoPedido,
                    i.FechaPedido
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM inserted i;
    END

    -- Para DELETE: registrar el estado anterior
    IF @Operacion = 'DELETE'
    BEGIN
        INSERT INTO Auditoria (Tabla, Operacion, RegistroID, DatosAntes)
        SELECT
            'Pedidos',
            'DELETE',
            d.PedidoID,
            (
                SELECT
                    d.PedidoID,
                    d.ClienteID,
                    d.Estado,
                    d.Total,
                    d.TipoPedido,
                    d.FechaPedido
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM deleted d;
    END
END
GO


/* ================================================================
   SECCIÓN 6: VISTAS DE CONSULTA FRECUENTE
   ================================================================ */

-- ----------------------------------------------------------------
-- VISTA: vw_MenuCompleto
-- Descripción: Menú completo con nombre de categoría y disponibilidad.
--              Utilizada por la web para mostrar el menú actualizado.
-- ----------------------------------------------------------------
CREATE OR ALTER VIEW vw_MenuCompleto AS
SELECT
    p.ProductoID,
    c.Nombre          AS Categoria,
    c.Orden           AS OrdenCategoria,
    p.Nombre          AS Producto,
    p.Descripcion,
    p.Precio,
    p.ImagenURL,
    p.Disponible,
    p.EsDestacado
FROM Productos p
INNER JOIN Categorias c ON c.CategoriaID = p.CategoriaID
WHERE p.Disponible = 1 AND c.Activo = 1;
GO


-- ----------------------------------------------------------------
-- VISTA: vw_PedidosHoy
-- Descripción: Todos los pedidos del día actual con su estado y total.
--              Para el panel de cocina/caja en tiempo real.
-- ----------------------------------------------------------------
CREATE OR ALTER VIEW vw_PedidosHoy AS
SELECT
    p.PedidoID,
    ISNULL(cl.Nombre, 'Cliente General')  AS Cliente,
    cl.Telefono,
    ISNULL(e.Nombre, 'N/A')               AS Empleado,
    p.TipoPedido,
    p.Estado,
    p.NumeroMesa,
    p.Total,
    p.Notas,
    p.FechaPedido
FROM Pedidos p
LEFT JOIN Clientes  cl ON cl.ClienteID  = p.ClienteID
LEFT JOIN Empleados e  ON e.EmpleadoID  = p.EmpleadoID
WHERE CAST(p.FechaPedido AS DATE) = CAST(GETDATE() AS DATE);
GO


-- ----------------------------------------------------------------
-- VISTA: vw_ProductosMasVendidos
-- Descripción: Top de productos vendidos en el último mes.
-- ----------------------------------------------------------------
CREATE OR ALTER VIEW vw_ProductosMasVendidos AS
SELECT TOP 10
    pr.Nombre            AS Producto,
    c.Nombre             AS Categoria,
    SUM(d.Cantidad)      AS TotalUnidades,
    SUM(d.Subtotal)      AS TotalIngresos
FROM DetallePedido d
INNER JOIN Pedidos   p  ON p.PedidoID   = d.PedidoID
INNER JOIN Productos pr ON pr.ProductoID = d.ProductoID
INNER JOIN Categorias c ON c.CategoriaID = pr.CategoriaID
WHERE
    p.FechaPedido >= DATEADD(MONTH, -1, GETDATE())
    AND p.Estado <> 'Cancelado'
GROUP BY pr.Nombre, c.Nombre
ORDER BY TotalUnidades DESC;
GO


/* ================================================================
   SECCIÓN 7: SQL SERVER AGENT JOB (Reporte automático diario)
   Descripción: Tarea programada que corre cada día a las 23:55
                y genera un registro de resumen en una tabla de reportes.
   Nota: Requiere SQL Server Agent habilitado.
   ================================================================ */

-- Tabla para almacenar los reportes diarios automáticos
CREATE TABLE ReportesDiarios (
    ReporteID     INT           NOT NULL IDENTITY(1,1),
    Fecha         DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    TotalPedidos  INT           NOT NULL,
    TotalIngresos DECIMAL(12,2) NOT NULL,
    PedidosMayores INT          NOT NULL,  -- Pedidos > C$500
    GeneradoEn    DATETIME2     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_ReportesDiarios PRIMARY KEY (ReporteID)
);
GO

-- Stored Procedure que usa el Job para generar el reporte
CREATE OR ALTER PROCEDURE usp_GenerarReporteDiario
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Fecha         DATE          = CAST(GETDATE() AS DATE);
    DECLARE @TotalPedidos  INT;
    DECLARE @TotalIngresos DECIMAL(12,2);
    DECLARE @PedidosMayor  INT;

    SELECT
        @TotalPedidos  = COUNT(*),
        @TotalIngresos = SUM(Total),
        @PedidosMayor  = SUM(CASE WHEN Total > 500 THEN 1 ELSE 0 END)
    FROM Pedidos
    WHERE
        CAST(FechaPedido AS DATE) = @Fecha
        AND Estado <> 'Cancelado';

    INSERT INTO ReportesDiarios (Fecha, TotalPedidos, TotalIngresos, PedidosMayores)
    VALUES (@Fecha, ISNULL(@TotalPedidos,0), ISNULL(@TotalIngresos,0), ISNULL(@PedidosMayor,0));

    PRINT 'Reporte diario generado para: ' + CAST(@Fecha AS NVARCHAR);
END
GO

/*
   Para crear el Job automático en SQL Server Agent:
   Ejecutar el siguiente bloque una vez con permisos de sysadmin.

EXEC msdb.dbo.sp_add_job
    @job_name = N'SaborDelaVida_ReporteDiario';

EXEC msdb.dbo.sp_add_jobstep
    @job_name  = N'SaborDelaVida_ReporteDiario',
    @step_name = N'Ejecutar SP Reporte',
    @command   = N'USE SaborDelaVida; EXEC usp_GenerarReporteDiario;',
    @database_name = N'SaborDelaVida';

EXEC msdb.dbo.sp_add_schedule
    @schedule_name    = N'Diario 23:55',
    @freq_type        = 4,        -- Diario
    @freq_interval    = 1,
    @active_start_time= 235500;   -- 23:55:00

EXEC msdb.dbo.sp_attach_schedule
    @job_name      = N'SaborDelaVida_ReporteDiario',
    @schedule_name = N'Diario 23:55';

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'SaborDelaVida_ReporteDiario';
*/


/* ================================================================
   SECCIÓN 8: CONSULTAS DE VERIFICACIÓN
   Descripción: Queries de comprobación para confirmar que la BD
                quedó correctamente configurada.
   ================================================================ */

-- Verificar tablas creadas
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO

-- Verificar productos cargados por categoría
SELECT c.Nombre AS Categoria, COUNT(*) AS TotalProductos
FROM Productos p
INNER JOIN Categorias c ON c.CategoriaID = p.CategoriaID
GROUP BY c.Nombre
ORDER BY c.Nombre;
GO

-- Ver el menú completo
SELECT * FROM vw_MenuCompleto ORDER BY OrdenCategoria, Producto;
GO

/* ================================================================
   FIN DEL SCRIPT — SaborDelaVida Database v1.0
   ================================================================ */
