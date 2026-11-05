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


-- ------------------------------------------------------------
-- 03.

-- ------------------------------------------------------------
-- 04

-- 

COMMIT;
