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

import sqlite3
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__, static_folder=".")

# Cupones validos y su descuento (0.20 = 20 %).
COUPONS = {"ECO20": 0.20}


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


@app.route("/api/checkout", methods=["POST"])
def checkout():
    data = request.json
    email = data.get("email")
    product_id = data.get("product_id")
    quantity = data.get("quantity")

    conn = get_db_connection()
    product = conn.execute(
        "SELECT * FROM products WHERE id = ?", (product_id,)).fetchone()

    if not product:
        conn.close()
        return jsonify({"error": "Producto no encontrado"}), 404

    total = product["price"] * quantity
    conn.close()

    return jsonify({
        "message": "Pedido realizado con exito",
        "order_details": {
            "email": email,
            "product": product["name"],
            "quantity": quantity,
            "total_pay": total,
            "date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        },
    }), 200


if __name__ == "__main__":
    app.run(debug=True, port=5000)
