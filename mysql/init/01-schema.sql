-- ========================================
-- ESQUEMA DE BASE DE DATOS PARA INVENTARIO TIENDA
-- Archivo de inicialización para contenedor MySQL Docker
-- ========================================

-- Crear base de datos si no existe
CREATE DATABASE IF NOT EXISTS inventario_tienda 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- Usar la base de datos
USE inventario_tienda;

-- ========================================
-- CREACIÓN DE TABLAS
-- ========================================

-- Tabla de Roles
CREATE TABLE IF NOT EXISTS roles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_roles_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de Usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    rol_id BIGINT NOT NULL,
    FOREIGN KEY (rol_id) REFERENCES roles(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_usuarios_username (username),
    INDEX idx_usuarios_email (email),
    INDEX idx_usuarios_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de Categorías
CREATE TABLE IF NOT EXISTS categorias (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_categorias_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de Productos
CREATE TABLE IF NOT EXISTS productos (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL CHECK (precio >= 0),
    stock_actual INT NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo INT NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
    categoria_id BIGINT NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_productos_categoria (categoria_id),
    INDEX idx_productos_stock_bajo (stock_actual, stock_minimo),
    INDEX idx_productos_nombre (nombre),
    INDEX idx_productos_precio (precio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de Movimientos
CREATE TABLE IF NOT EXISTS movimientos (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    producto_id BIGINT NOT NULL,
    usuario_id BIGINT NOT NULL,
    tipo_movimiento ENUM('ENTRADA', 'SALIDA') NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    motivo VARCHAR(255),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_movimientos_producto (producto_id),
    INDEX idx_movimientos_usuario (usuario_id),
    INDEX idx_movimientos_fecha (fecha),
    INDEX idx_movimientos_tipo (tipo_movimiento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- INSERCIÓN DE DATOS INICIALES
-- ========================================

-- Insertar roles básicos
INSERT INTO roles (nombre, descripcion) VALUES
('ADMIN', 'Administrador del sistema con acceso completo'),
('GERENTE', 'Gerente con permisos de gestión de inventario y usuarios'),
('EMPLEADO', 'Empleado con permisos básicos de consulta y registro')
ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion);

-- Insertar categorías de ejemplo
INSERT INTO categorias (nombre, descripcion) VALUES
('Electrónicos', 'Dispositivos electrónicos y tecnología'),
('Ropa', 'Prendas de vestir y accesorios'),
('Hogar', 'Artículos para el hogar'),
('Deportes', 'Equipos y artículos deportivos'),
('Libros', 'Libros y material de lectura'),
('Alimentación', 'Productos alimenticios y bebidas'),
('Salud y Belleza', 'Productos de cuidado personal y salud'),
('Juguetes', 'Juguetes y juegos para niños'),
('Automóvil', 'Accesorios y repuestos para vehículos'),
('Oficina', 'Suministros y equipos de oficina')
ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion);

-- Insertar usuario administrador por defecto 
-- Password: admin123 (hasheada con BCrypt)
INSERT INTO usuarios (username, password, nombre_completo, email, rol_id) VALUES
('admin', '$2a$10$N.kmcuVb78KtCrvkJfbn4.9z7POt1c/Ls/zqJ6f/l3hGEJd9nTu5G', 'Administrador Sistema', 'admin@tienda.com', 1),
('gerente', '$2a$10$N.kmcuVb78KtCrvkJfbn4.9z7POt1c/Ls/zqJ6f/l3hGEJd9nTu5G', 'Gerente General', 'gerente@tienda.com', 2),
('empleado', '$2a$10$N.kmcuVb78KtCrvkJfbn4.9z7POt1c/Ls/zqJ6f/l3hGEJd9nTu5G', 'Empleado Tienda', 'empleado@tienda.com', 3)
ON DUPLICATE KEY UPDATE 
    nombre_completo = VALUES(nombre_completo),
    email = VALUES(email);

-- ========================================
-- CREACIÓN DE VISTAS
-- ========================================

-- Vista para consultas frecuentes de productos con stock
CREATE OR REPLACE VIEW vista_productos_stock AS
SELECT
    p.id,
    p.nombre,
    p.descripcion,
    p.precio,
    p.stock_actual,
    p.stock_minimo,
    c.nombre as categoria,
    p.fecha_creacion,
    p.fecha_actualizacion,
    CASE
        WHEN p.stock_actual <= 0 THEN 'AGOTADO'
        WHEN p.stock_actual <= p.stock_minimo THEN 'CRÍTICO'
        WHEN p.stock_actual <= (p.stock_minimo * 1.5) THEN 'BAJO'
        ELSE 'NORMAL'
    END as estado_stock,
    CASE
        WHEN p.stock_actual <= p.stock_minimo THEN 1
        WHEN p.stock_actual <= (p.stock_minimo * 1.5) THEN 2
        ELSE 3
    END as prioridad_restock
FROM productos p
JOIN categorias c ON p.categoria_id = c.id;

-- Vista para historial de movimientos con información detallada
CREATE OR REPLACE VIEW vista_historial_movimientos AS
SELECT
    m.id,
    p.nombre as producto,
    p.precio as precio_producto,
    u.nombre_completo as usuario,
    u.username as username,
    m.tipo_movimiento,
    m.cantidad,
    m.motivo,
    m.fecha,
    c.nombre as categoria,
    (m.cantidad * p.precio) as valor_movimiento,
    p.stock_actual as stock_actual_producto
FROM movimientos m
JOIN productos p ON m.producto_id = p.id
JOIN usuarios u ON m.usuario_id = u.id
JOIN categorias c ON p.categoria_id = c.id
ORDER BY m.fecha DESC;

-- Vista para resumen de productos por categoría
CREATE OR REPLACE VIEW vista_resumen_categorias AS
SELECT
    c.id,
    c.nombre as categoria,
    c.descripcion,
    COUNT(p.id) as total_productos,
    SUM(p.stock_actual) as stock_total,
    SUM(p.stock_actual * p.precio) as valor_inventario,
    AVG(p.precio) as precio_promedio,
    COUNT(CASE WHEN p.stock_actual <= p.stock_minimo THEN 1 END) as productos_stock_bajo
FROM categorias c
LEFT JOIN productos p ON c.id = p.categoria_id
GROUP BY c.id, c.nombre, c.descripcion;

-- ========================================
-- DATOS DE EJEMPLO PARA TESTING (OPCIONAL)
-- ========================================

-- Insertar algunos productos de ejemplo
INSERT INTO productos (nombre, descripcion, precio, stock_actual, stock_minimo, categoria_id) VALUES
('Laptop Dell Inspiron 15', 'Laptop para uso profesional con 8GB RAM y SSD 256GB', 1299.99, 15, 5, 1),
('Smartphone Samsung Galaxy A54', 'Teléfono inteligente con cámara de 50MP', 349.99, 25, 10, 1),
('Camiseta Polo Ralph Lauren', 'Camiseta de algodón 100% color azul marino', 89.99, 50, 15, 2),
('Pantalón Jeans Levi''s 501', 'Pantalón clásico de mezclilla', 79.99, 30, 10, 2),
('Cafetera Oster 12 Tazas', 'Cafetera automática programable', 45.99, 8, 3, 3),
('Balón Fútbol Nike', 'Balón oficial FIFA para fútbol profesional', 29.99, 20, 8, 4),
('El Quijote de la Mancha', 'Libro clásico de Miguel de Cervantes', 19.99, 12, 5, 5)
ON DUPLICATE KEY UPDATE 
    descripcion = VALUES(descripcion),
    precio = VALUES(precio);

-- Insertar algunos movimientos de ejemplo
INSERT INTO movimientos (producto_id, usuario_id, tipo_movimiento, cantidad, motivo) VALUES
(1, 1, 'ENTRADA', 10, 'Compra inicial de inventario'),
(2, 1, 'ENTRADA', 15, 'Reposición de stock'),
(3, 2, 'SALIDA', 5, 'Venta en mostrador'),
(4, 3, 'ENTRADA', 20, 'Llegada de nueva colección'),
(1, 2, 'SALIDA', 2, 'Venta online'),
(5, 1, 'ENTRADA', 5, 'Compra de electrodomésticos')
ON DUPLICATE KEY UPDATE motivo = VALUES(motivo);

-- ========================================
-- CONFIGURACIONES FINALES DE LA BASE DE DATOS
-- ========================================

-- Configurar el motor de almacenamiento por defecto
SET default_storage_engine = InnoDB;

-- Configurar zona horaria
SET time_zone = '-05:00';

-- Habilitar el modo estricto de SQL
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- Mensaje de confirmación
SELECT 'Base de datos inventario_tienda inicializada correctamente' as mensaje;

-- Mostrar resumen de la base de datos creada
SELECT 
    'Tablas creadas' as tipo,
    COUNT(*) as cantidad
FROM information_schema.tables 
WHERE table_schema = 'inventario_tienda'
UNION ALL
SELECT 
    'Vistas creadas' as tipo,
    COUNT(*) as cantidad
FROM information_schema.views 
WHERE table_schema = 'inventario_tienda';