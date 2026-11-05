-- ============================================================
-- saneado.sql
-- Correcciones sobre database.sqlite (Eco-Shop)
-- Se ejecuta sobre la base de datos generada con setup_db.py
--
-- Regla: cada correccion lleva su comentario sobre el problema que resuelve, y el script SQL.-- ============================================================

-- 01. Solventar el PRAGMA foreign_keys = ON
--Activar en cada conexión con sqlite3 database.sqlite
RAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- ------------------------------------------------------------
-- 02. Actualizar los datos de los pedidos 503 y 504
-- El pedido 504 apunta al producto 999, que no existe. Se reasigna al producto 104.
UPDATE orders
SET product_id = 104
WHERE id = 504
  AND product_id = 999;

-- El pedido 503 tiene user_id 99 y ese usuario no existe.
-- No hay otro dato para reasignarlo, así que se elimina la fila.
DELETE FROM orders
WHERE id = 503
  AND user_id = 99;

-- ------------------------------------------------------------
-- 03. Reunificación de idiomas en pedidos status y user status
-- Carmen Díaz (3) tiene 'activo' y el resto de usuarios usa 'active'.
-- Se unifica el estado para que un filtro por 'active' la incluya.
UPDATE users
SET status = 'active'
WHERE id = 3
  AND status = 'activo';

-- El pedido 506 dice ENTREGADO y el 501 dice DELIVERED para el mismo hecho.
UPDATE orders
SET status = 'DELIVERED'
WHERE id = 506
  AND status = 'ENTREGADO';
-- ------------------------------------------------------------
-- 04 Unicidad en los emails de usuarios siguiendo el modelo de email de la base de datos
UPDATE users
SET email = 'diego.salas@example.com'
WHERE id = 4
  AND email = 'bruno@example.com';

  -- 05.Actualizaciones de precios con signos negativos
  -- La botella reutilizable (106) tiene precio -12.90. Se quita el signo.
UPDATE products
SET price = 12.90
WHERE id = 106
  AND price = -12.90;
-- El cepillo de bambú (102) tiene stock -5. Se quita el signo.
UPDATE products
SET stock = 5
WHERE id = 102
  AND stock = -5;
  -- ------------------------------------------------------------
-- 06. Corregir los pedidos 504, 508, 507 y 503
-- El pedido 504 apunta al producto 999, que no existe.
UPDATE orders
SET product_id = 104
WHERE id = 504
  AND product_id = 999;
  -- ------------------------------------------------------------
-- El pedido 508 cobra 50.00 por 2 jabones a 5.00. El total de la línea es 10.00.
UPDATE orders
SET total = (
    SELECT ROUND(p.price * orders.quantity, 2)
    FROM products p
    WHERE p.id = orders.product_id
)
WHERE id = 508
  AND product_id = 101
  AND quantity = 2
  AND total = 50.00;
  -- ------------------------------------------------------------
-- El pedido 507 tiene cantidad -2 y total -4.00 sobre la bolsa a 2.00.
-- El importe ya sigue al precio; solo está invertido el signo: 2 unidades y 4.00.
UPDATE orders
SET quantity = 2,
    total = 4.00
WHERE id = 507
  AND product_id = 103
  AND quantity = -2
  AND total = -4.00;
  -- ------------------------------------------------------------
-- El pedido 503 tiene user_id 99 y ese usuario no existe.
-- No hay otro dato para reasignarlo, así que se elimina la fila.
DELETE FROM orders
WHERE id = 503
  AND user_id = 99;


COMMIT;
