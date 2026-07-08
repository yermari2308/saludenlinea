"""
Farmacia en línea.

Flujo del paciente:
  GET  /api/pharmacy/products          → catálogo (filtro por categoría)
  POST /api/pharmacy/cart              → agregar producto
  GET  /api/pharmacy/cart              → ver carrito
  PUT  /api/pharmacy/cart/{item_id}    → cambiar cantidad
  DELETE /api/pharmacy/cart/{item_id}  → quitar del carrito
  POST /api/pharmacy/checkout          → crear pedido (valida receta si aplica)
  GET  /api/pharmacy/orders            → historial de pedidos

Admin (header X-Admin-Key):
  POST/PUT/DELETE /api/pharmacy/admin/products, GET /admin/orders, PUT /admin/orders/{id}
"""
import os
import logging
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, field_validator
from database import get_db
from models import PharmacyProduct, CartItem, PharmacyOrder, OrderItem, Appointment
from utils.auth import require_patient

logger = logging.getLogger("saludenlinea")

router = APIRouter(prefix="/api/pharmacy", tags=["pharmacy"])

ADMIN_KEY = os.getenv("ADMIN_KEY", "saludenlinea-admin-2025")

CATEGORIAS = ["general", "analgesicos", "vitaminas", "cuidado_personal", "cronicos"]


# ── Pydantic ──────────────────────────────────────────────────────────────────

class CartAddRequest(BaseModel):
    producto_id: int
    cantidad: int = Field(default=1, ge=1, le=20)


class CartUpdateRequest(BaseModel):
    cantidad: int = Field(ge=1, le=20)


class CheckoutRequest(BaseModel):
    direccion_entrega: str = Field(min_length=10, max_length=500)
    metodo_pago: str = Field(default="sinpe")

    @field_validator("metodo_pago")
    @classmethod
    def metodo_valido(cls, v: str) -> str:
        if v not in ("sinpe", "contra_entrega"):
            raise ValueError("Método de pago debe ser sinpe o contra_entrega")
        return v


class ProductRequest(BaseModel):
    nombre: str = Field(min_length=2, max_length=150)
    descripcion: str = Field(default="", max_length=2000)
    precio: float = Field(gt=0, le=10000)
    requiere_receta: bool = False
    stock: int = Field(default=0, ge=0)
    imagen_url: str = Field(default="", max_length=500)
    categoria: str = Field(default="general")

    @field_validator("categoria")
    @classmethod
    def cat_valida(cls, v: str) -> str:
        if v not in CATEGORIAS:
            raise ValueError(f"Categoría debe ser una de: {', '.join(CATEGORIAS)}")
        return v


class OrderStatusRequest(BaseModel):
    estado: str

    @field_validator("estado")
    @classmethod
    def estado_valido(cls, v: str) -> str:
        if v not in ("pendiente", "confirmado", "enviado", "entregado", "cancelado"):
            raise ValueError("Estado no válido")
        return v


# ── Helpers ───────────────────────────────────────────────────────────────────

def _serialize_product(p: PharmacyProduct) -> dict:
    return {
        "id": p.id,
        "nombre": p.nombre,
        "descripcion": p.descripcion,
        "precio": p.precio,
        "requiere_receta": p.requiere_receta,
        "stock": p.stock,
        "imagen_url": p.imagen_url,
        "categoria": p.categoria,
    }


def _paciente_tiene_receta(paciente_id: int, db: Session) -> bool:
    """El paciente tiene al menos una receta emitida en alguna cita."""
    return db.query(Appointment).filter(
        Appointment.paciente_id == paciente_id,
        (Appointment.receta_texto != "") | (Appointment.receta_archivo_b64 != ""),
    ).first() is not None


def _check_admin(key: str):
    if key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")


# ── Catálogo ──────────────────────────────────────────────────────────────────

@router.get("/products")
def listar_productos(
    categoria: Optional[str] = None,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    q = db.query(PharmacyProduct).filter(PharmacyProduct.activo == True)  # noqa: E712
    if categoria and categoria in CATEGORIAS:
        q = q.filter(PharmacyProduct.categoria == categoria)
    return [_serialize_product(p) for p in q.order_by(PharmacyProduct.nombre).all()]


@router.get("/categories")
def listar_categorias(current=Depends(require_patient)):
    return CATEGORIAS


# ── Carrito ───────────────────────────────────────────────────────────────────

@router.get("/cart")
def ver_carrito(db: Session = Depends(get_db), current=Depends(require_patient)):
    items = db.query(CartItem).filter(
        CartItem.paciente_id == int(current["sub"])
    ).order_by(CartItem.agregado_en).all()
    result = []
    total = 0.0
    for it in items:
        if not it.producto or not it.producto.activo:
            continue
        subtotal = it.producto.precio * it.cantidad
        total += subtotal
        result.append({
            "item_id": it.id,
            "cantidad": it.cantidad,
            "subtotal": round(subtotal, 2),
            "producto": _serialize_product(it.producto),
        })
    return {"items": result, "total": round(total, 2)}


@router.post("/cart")
def agregar_al_carrito(
    data: CartAddRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])
    producto = db.query(PharmacyProduct).filter(
        PharmacyProduct.id == data.producto_id,
        PharmacyProduct.activo == True,  # noqa: E712
    ).first()
    if not producto:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    if producto.stock < data.cantidad:
        raise HTTPException(status_code=400, detail="Stock insuficiente")

    existente = db.query(CartItem).filter(
        CartItem.paciente_id == paciente_id,
        CartItem.producto_id == data.producto_id,
    ).first()
    if existente:
        existente.cantidad = min(existente.cantidad + data.cantidad, 20)
    else:
        db.add(CartItem(
            paciente_id=paciente_id,
            producto_id=data.producto_id,
            cantidad=data.cantidad,
        ))
    db.commit()
    return {"mensaje": "Agregado al carrito"}


@router.put("/cart/{item_id}")
def actualizar_cantidad(
    item_id: int,
    data: CartUpdateRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.paciente_id == int(current["sub"]),
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item no encontrado")
    item.cantidad = data.cantidad
    db.commit()
    return {"mensaje": "Cantidad actualizada"}


@router.delete("/cart/{item_id}")
def quitar_del_carrito(
    item_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.paciente_id == int(current["sub"]),
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item no encontrado")
    db.delete(item)
    db.commit()
    return {"mensaje": "Eliminado del carrito"}


# ── Checkout ──────────────────────────────────────────────────────────────────

@router.post("/checkout")
def checkout(
    data: CheckoutRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])
    items = db.query(CartItem).filter(CartItem.paciente_id == paciente_id).all()
    if not items:
        raise HTTPException(status_code=400, detail="El carrito está vacío")

    # Validaciones previas
    con_receta = [it for it in items if it.producto and it.producto.requiere_receta]
    if con_receta and not _paciente_tiene_receta(paciente_id, db):
        nombres = ", ".join(it.producto.nombre for it in con_receta)
        raise HTTPException(
            status_code=400,
            detail=f"Estos productos requieren receta médica: {nombres}. "
                   "Agenda una consulta para obtenerla.",
        )
    for it in items:
        if not it.producto or not it.producto.activo:
            raise HTTPException(status_code=400, detail="Un producto del carrito ya no está disponible")
        if it.producto.stock < it.cantidad:
            raise HTTPException(
                status_code=400,
                detail=f"Stock insuficiente de {it.producto.nombre} (quedan {it.producto.stock})",
            )

    # Crear pedido
    total = sum(it.producto.precio * it.cantidad for it in items)
    orden = PharmacyOrder(
        paciente_id=paciente_id,
        total=round(total, 2),
        estado="pendiente",
        direccion_entrega=data.direccion_entrega,
        metodo_pago=data.metodo_pago,
    )
    db.add(orden)
    db.flush()  # obtener orden.id

    for it in items:
        db.add(OrderItem(
            order_id=orden.id,
            producto_id=it.producto_id,
            cantidad=it.cantidad,
            precio_unitario=it.producto.precio,
        ))
        it.producto.stock -= it.cantidad
        db.delete(it)

    db.commit()
    logger.info("Pedido farmacia creado id=%s paciente=%s total=%s", orden.id, paciente_id, orden.total)
    return {
        "mensaje": "Pedido creado. Te contactaremos para coordinar la entrega.",
        "order_id": orden.id,
        "total": orden.total,
        "metodo_pago": orden.metodo_pago,
    }


# ── Historial ─────────────────────────────────────────────────────────────────

@router.get("/orders")
def mis_pedidos(db: Session = Depends(get_db), current=Depends(require_patient)):
    ordenes = db.query(PharmacyOrder).filter(
        PharmacyOrder.paciente_id == int(current["sub"])
    ).order_by(PharmacyOrder.creado_en.desc()).limit(30).all()
    return [
        {
            "id": o.id,
            "total": o.total,
            "estado": o.estado,
            "direccion_entrega": o.direccion_entrega,
            "metodo_pago": o.metodo_pago,
            "creado_en": o.creado_en.isoformat(),
            "items": [
                {
                    "nombre": i.producto.nombre if i.producto else "(eliminado)",
                    "cantidad": i.cantidad,
                    "precio_unitario": i.precio_unitario,
                }
                for i in o.items
            ],
        }
        for o in ordenes
    ]


# ── Admin: productos y pedidos ────────────────────────────────────────────────

@router.post("/admin/products")
def crear_producto(
    data: ProductRequest,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    _check_admin(x_admin_key)
    p = PharmacyProduct(**data.model_dump())
    db.add(p)
    db.commit()
    db.refresh(p)
    return _serialize_product(p)


@router.put("/admin/products/{product_id}")
def editar_producto(
    product_id: int,
    data: ProductRequest,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    _check_admin(x_admin_key)
    p = db.query(PharmacyProduct).filter(PharmacyProduct.id == product_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    for k, v in data.model_dump().items():
        setattr(p, k, v)
    db.commit()
    return _serialize_product(p)


@router.delete("/admin/products/{product_id}")
def desactivar_producto(
    product_id: int,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    _check_admin(x_admin_key)
    p = db.query(PharmacyProduct).filter(PharmacyProduct.id == product_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    p.activo = False
    db.commit()
    return {"mensaje": "Producto desactivado"}


@router.get("/admin/orders")
def admin_pedidos(
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    _check_admin(x_admin_key)
    ordenes = db.query(PharmacyOrder).order_by(
        PharmacyOrder.creado_en.desc()).limit(100).all()
    return [
        {
            "id": o.id,
            "paciente_id": o.paciente_id,
            "paciente_nombre": o.paciente.nombre if o.paciente else "",
            "total": o.total,
            "estado": o.estado,
            "direccion_entrega": o.direccion_entrega,
            "metodo_pago": o.metodo_pago,
            "creado_en": o.creado_en.isoformat(),
        }
        for o in ordenes
    ]


@router.put("/admin/orders/{order_id}")
def admin_actualizar_pedido(
    order_id: int,
    data: OrderStatusRequest,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    _check_admin(x_admin_key)
    o = db.query(PharmacyOrder).filter(PharmacyOrder.id == order_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")
    o.estado = data.estado
    db.commit()
    return {"mensaje": f"Pedido {order_id} → {data.estado}"}


# ── Seed inicial (solo si el catálogo está vacío) ─────────────────────────────

def seed_products(db: Session):
    if db.query(PharmacyProduct).first():
        return
    productos = [
        ("Acetaminofén 500mg (20 tabs)", "Analgésico y antipirético para dolor leve y fiebre.", 3.50, False, 100, "analgesicos"),
        ("Ibuprofeno 400mg (20 tabs)", "Antiinflamatorio no esteroideo para dolor e inflamación.", 4.25, False, 100, "analgesicos"),
        ("Vitamina C 1000mg (30 tabs)", "Refuerza el sistema inmune.", 8.90, False, 80, "vitaminas"),
        ("Multivitamínico adulto (60 tabs)", "Complejo de vitaminas y minerales de uso diario.", 12.50, False, 60, "vitaminas"),
        ("Losartán 50mg (30 tabs)", "Antihipertensivo. Requiere receta médica.", 9.75, True, 50, "cronicos"),
        ("Metformina 850mg (30 tabs)", "Control de glucosa en diabetes tipo 2. Requiere receta.", 7.80, True, 50, "cronicos"),
        ("Amoxicilina 500mg (21 caps)", "Antibiótico de amplio espectro. Requiere receta.", 11.20, True, 40, "cronicos"),
        ("Alcohol en gel 250ml", "Desinfectante de manos 70% alcohol.", 2.95, False, 150, "cuidado_personal"),
        ("Termómetro digital", "Medición rápida de temperatura corporal.", 6.50, False, 30, "cuidado_personal"),
        ("Suero oral (6 sobres)", "Rehidratación para episodios de diarrea o vómito.", 4.10, False, 90, "general"),
    ]
    for nombre, desc, precio, receta, stock, cat in productos:
        db.add(PharmacyProduct(
            nombre=nombre, descripcion=desc, precio=precio,
            requiere_receta=receta, stock=stock, categoria=cat,
        ))
    db.commit()
    logger.info("Seed de farmacia: %d productos creados", len(productos))
