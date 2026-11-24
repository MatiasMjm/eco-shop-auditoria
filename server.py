# -*- coding: utf-8 -*-
"""
server.py

Servidor de Eco-Shop. Sirve la pagina de compra y expone dos rutas de la API:
el calculo de descuentos y el cierre de pedido.

Como se arranca:

    python setup_db.py     (solo la primera vez, crea la base de datos)
    python server.py

Despues, abre http://127.0.0.1:5000 en el navegador.
"""

from datetime import datetime
import math
import re 
import sqlite3
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__, static_folder=".")

# Cupones validos y su descuento (0.20 = 20 %).
COUPONS = {"ECO20": 0.20}

# Formato minimo de email: algo@dominio.ext, sin espacios.
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

def discount_error(message):
    """Respuesta de error uniforme para /api/discount (HTTP 400)."""
    return jsonify({"status": "error", "error": message}), 400

def get_db_connection():
    conn = sqlite3.connect("database.sqlite")
    conn.row_factory = sqlite3.Row
    return conn


@app.route("/")
def home():
    """Sirve la pagina de compra."""
    return send_from_directory(".", "index.html")


@app.route("/api/discount", methods=["POST"])
def apply_discount():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return discount_error("El cuerpo debe ser un JSON valido")

    # --- Validacion del precio ---
    if "price" not in data:
        return discount_error("El precio es obligatorio")
    price = data["price"]
    if price is None:
        return discount_error("El precio no puede ser null")
    # bool es subclase de int en Python: se rechaza de forma explicita.
    if isinstance(price, bool) or not isinstance(price, (int, float)):
        return discount_error("El precio debe ser un numero")
    if not math.isfinite(price):
        return discount_error("El precio debe ser un numero finito")
    if price < 0:
        return discount_error("El precio no puede ser negativo")
    if price == 0:
        return discount_error("El precio debe ser mayor que cero")

    # --- Validacion del cupon ---
    # Sin cupon (ausente, null o cadena vacia): precio sin descuento.
    coupon = data.get("coupon")
    if coupon is None or coupon == "":
        rate = 0.0
    elif not isinstance(coupon, str):
        return discount_error("El cupon debe ser una cadena de texto")
    elif coupon in COUPONS:
        rate = COUPONS[coupon]
    else:
        return discount_error("Cupon no valido")

    final_price = round(price - (price * rate), 2)

    return jsonify({
        "status": "success",
        "original_price": price,
        "discount_applied": f"{int(rate * 100)}%",
        "final_price": final_price,
    })


def checkout_error(field, message, code=400):
    """Respuesta de error uniforme para /api/checkout: indica el campo que falla."""
    return jsonify({"status": "error", "field": field, "error": message}), code


def is_integer(value):
    """True si value es un entero JSON (bool es subclase de int: se excluye)."""
    return isinstance(value, int) and not isinstance(value, bool)

@app.route("/api/checkout", methods=["POST"])
def checkout():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return checkout_error("body", "El cuerpo debe ser un JSON valido")

    # --- Validacion de entrada (antes de tocar la base de datos) ---
    email = data.get("email")
    if not isinstance(email, str) or not EMAIL_RE.match(email):
        return checkout_error("email", "El email es obligatorio y debe tener un formato valido")

    product_id = data.get("product_id")
    if not is_integer(product_id):
        return checkout_error("product_id", "El product_id es obligatorio y debe ser un entero")

    quantity = data.get("quantity")
    if "quantity" not in data or quantity is None:
        return checkout_error("quantity", "La cantidad es obligatoria")
    if not is_integer(quantity):
        return checkout_error("quantity", "La cantidad debe ser un numero entero")
    if quantity <= 0:
        return checkout_error("quantity", "La cantidad debe ser mayor que cero")

    conn = get_db_connection()
    try:
        product = conn.execute(
            "SELECT * FROM products WHERE id = ?", (product_id,)).fetchone()
        if not product:
            return checkout_error("product_id", "Producto no encontrado", 404)

        if product["stock"] < quantity:
            return checkout_error(
                "quantity",
                "Existencias insuficientes: quedan %d unidades" % max(product["stock"], 0))

        total = round(product["price"] * quantity, 2)

        # Usuario asociado al email; si no existe, el pedido queda sin user_id.
        user = conn.execute(
            "SELECT id FROM users WHERE email = ? ORDER BY id LIMIT 1", (email,)).fetchone()
        user_id = user["id"] if user else None

        # Descontar stock y crear el pedido en una unica transaccion.
        # El UPDATE condicional evita dejar el stock en negativo si dos
        # compras simultaneas piden la ultima unidad.
        with conn:
            updated = conn.execute(
                "UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?",
                (quantity, product_id, quantity))
            if updated.rowcount != 1:
                return checkout_error("quantity", "Existencias insuficientes")
            cursor = conn.execute(
                "INSERT INTO orders (user_id, product_id, quantity, total, status) "
                "VALUES (?, ?, ?, ?, ?)",
                (user_id, product_id, quantity, total, "PENDING"))
            order_id = cursor.lastrowid
    finally:
        conn.close()

    return jsonify({
        "message": "Pedido realizado con exito",
        "order_details": {
            "order_id": order_id,
            "email": email,
            "product": product["name"],
            "quantity": quantity,
            "total_pay": total,
            "date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        },
    }), 200


if __name__ == "__main__":
    app.run(debug=True, port=5000)
