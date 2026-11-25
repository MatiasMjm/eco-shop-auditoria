-- =====================================================================
-- comprobaciones.sql
-- Consultas que deben devolver CERO filas en una base de datos sana.
-- Esquema: users(id, name, email, status), products(id, name, price, stock),
--          orders(id, user_id, product_id, quantity, total, status)
--
-- Convención:
--   * Cada consulta devuelve las filas que violan la regla (columna "check_id" primero).
--   * UMBRAL: número máximo de filas tolerado. Salvo que se indique, es 0.
--   * Severidad: CRITICA = integridad/dinero, MEDIA = calidad de datos, AVISO = regla de negocio a validar.
--   * Valores válidos asumidos (confirmar con negocio):
--       users.status  IN ('active','inactive')
--       orders.status IN ('PENDING','PAID','DELIVERED')
-- =====================================================================


-- ---------------------------------------------------------------------
-- INTEGRIDAD REFERENCIAL
-- ---------------------------------------------------------------------

-- C01 [CRITICA] Pedidos sin usuario (user_id NULL).
-- Umbral: 0 filas. Todo pedido debe pertenecer a un usuario.
SELECT 'C01_pedido_sin_usuario' AS check_id, o.*
FROM orders o
WHERE o.user_id IS NULL;

-- C02 [CRITICA] Pedidos que apuntan a un usuario inexistente.
-- Umbral: 0 filas. user_id debe existir en users.id.
SELECT 'C02_pedido_usuario_huerfano' AS check_id, o.*
FROM orders o
LEFT JOIN users u ON u.id = o.user_id
WHERE o.user_id IS NOT NULL AND u.id IS NULL;

-- C03 [CRITICA] Pedidos que apuntan a un producto inexistente (o sin producto).
-- Umbral: 0 filas. product_id debe existir en products.id.
SELECT 'C03_pedido_producto_huerfano' AS check_id, o.*
FROM orders o
LEFT JOIN products p ON p.id = o.product_id
WHERE p.id IS NULL;


-- ---------------------------------------------------------------------
-- IMPORTES Y CANTIDADES
-- ---------------------------------------------------------------------

-- C04 [CRITICA] Cantidad nula, cero o negativa.
-- Umbral: 0 filas. quantity debe ser un entero >= 1.
SELECT 'C04_cantidad_no_positiva' AS check_id, o.*
FROM orders o
WHERE o.quantity IS NULL OR o.quantity <= 0;

-- C05 [CRITICA] Total del pedido distinto de cantidad x precio actual del producto.
-- Umbral: 0 filas (tolerancia de redondeo: 0.005).
SELECT 'C05_total_incoherente' AS check_id, o.*,
       p.price AS precio_producto,
       ROUND(o.quantity * p.price, 2) AS total_esperado
FROM orders o
JOIN products p ON p.id = o.product_id
WHERE o.total IS NULL
   OR ABS(o.total - o.quantity * p.price) > 0.005;

-- C06 [CRITICA] Total negativo.
-- Umbral: 0 filas. Un pedido no puede tener importe < 0.
SELECT 'C06_total_negativo' AS check_id, o.*
FROM orders o
WHERE o.total < 0;

-- C07 [CRITICA] Productos con precio negativo o nulo.
-- Umbral: 0 filas. price debe ser >= 0 y no nulo.
SELECT 'C07_precio_invalido' AS check_id, p.*
FROM products p
WHERE p.price IS NULL OR p.price < 0;

-- C08 [AVISO] Productos con precio cero.
-- Umbral: 0 filas. Un precio 0 solo es válido para muestras/regalos: revisar y, si procede, excluir por id.
SELECT 'C08_precio_cero' AS check_id, p.*
FROM products p
WHERE p.price = 0;

-- C09 [CRITICA] Stock negativo o nulo.
-- Umbral: 0 filas. stock debe ser un entero >= 0.
SELECT 'C09_stock_invalido' AS check_id, p.*
FROM products p
WHERE p.stock IS NULL OR p.stock < 0;


-- ---------------------------------------------------------------------
-- VALORES DE ESTADO (catálogos)
-- ---------------------------------------------------------------------

-- C10 [MEDIA] Estado de usuario fuera del catálogo (p. ej. 'activo' en vez de 'active').
-- Umbral: 0 filas. Solo 'active' o 'inactive'.
SELECT 'C10_estado_usuario_invalido' AS check_id, u.*
FROM users u
WHERE u.status IS NULL OR u.status NOT IN ('active', 'inactive');

-- C11 [MEDIA] Estado de pedido fuera del catálogo (p. ej. 'ENTREGADO' en vez de 'DELIVERED').
-- Umbral: 0 filas. Solo 'PENDING', 'PAID' o 'DELIVERED'.
SELECT 'C11_estado_pedido_invalido' AS check_id, o.*
FROM orders o
WHERE o.status IS NULL OR o.status NOT IN ('PENDING', 'PAID', 'DELIVERED');


-- ---------------------------------------------------------------------
-- CALIDAD DE DATOS DE USUARIOS Y PRODUCTOS
-- ---------------------------------------------------------------------

-- C12 [MEDIA] Emails duplicados (sin distinguir mayúsculas ni espacios).
-- Umbral: 0 filas. Cada email debe pertenecer a un único usuario.
SELECT 'C12_email_duplicado' AS check_id, u.*
FROM users u
WHERE LOWER(TRIM(u.email)) IN (
    SELECT LOWER(TRIM(email))
    FROM users
    WHERE email IS NOT NULL
    GROUP BY LOWER(TRIM(email))
    HAVING COUNT(*) > 1
)
ORDER BY LOWER(TRIM(u.email)), u.id;

-- C13 [MEDIA] Email nulo, vacío o con formato inválido.
-- Umbral: 0 filas. Debe contener '@' y un '.' posterior, sin espacios.
SELECT 'C13_email_invalido' AS check_id, u.*
FROM users u
WHERE u.email IS NULL
   OR TRIM(u.email) = ''
   OR u.email LIKE '% %'
   OR u.email NOT LIKE '_%@_%._%';

-- C14 [MEDIA] Nombres vacíos o nulos en usuarios o productos.
-- Umbral: 0 filas.
SELECT 'C14_nombre_vacio_usuario' AS check_id, u.id, u.name
FROM users u
WHERE u.name IS NULL OR TRIM(u.name) = ''
UNION ALL
SELECT 'C14_nombre_vacio_producto', p.id, p.name
FROM products p
WHERE p.name IS NULL OR TRIM(p.name) = '';

-- C15 [MEDIA] Productos con nombre duplicado.
-- Umbral: 0 filas.
SELECT 'C15_producto_duplicado' AS check_id, p.*
FROM products p
WHERE LOWER(TRIM(p.name)) IN (
    SELECT LOWER(TRIM(name))
    FROM products
    GROUP BY LOWER(TRIM(name))
    HAVING COUNT(*) > 1
);


-- ---------------------------------------------------------------------
-- REGLAS DE NEGOCIO
-- ---------------------------------------------------------------------

-- C16 [AVISO] Pedidos abiertos (PENDING/PAID) de usuarios no activos.
-- Umbral: 0 filas. Un usuario inactivo no debería tener pedidos abiertos. 
SELECT 'C16_pedido_de_usuario_inactivo' AS check_id, o.*, u.status AS estado_usuario
FROM orders o
JOIN users u ON u.id = o.user_id
WHERE u.status <> 'active'
  AND o.status IN ('PENDING', 'PAID');

-- C17 [AVISO] Pedidos abiertos (PENDING/PAID) de productos sin stock.
-- Umbral: 0 filas. No debería venderse un producto con stock <= 0. 
SELECT 'C17_pedido_producto_sin_stock' AS check_id, o.*, p.stock
FROM orders o
JOIN products p ON p.id = o.product_id
WHERE p.stock <= 0
  AND o.status IN ('PENDING', 'PAID');


-- ---------------------------------------------------------------------
-- INTEGRIDAD DEL MOTOR (ejecutar aparte)
-- ---------------------------------------------------------------------
-- PRAGMA integrity_check;     -- debe devolver una sola fila: 'ok'
-- PRAGMA foreign_key_check;   -- debe devolver cero filas
