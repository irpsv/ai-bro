from dataclasses import dataclass


@dataclass
class Order:
    id: int
    owner_id: int
    total: int


ORDERS = {
    1: Order(id=1, owner_id=10, total=100),
    2: Order(id=2, owner_id=20, total=250),
}


def get_current_user_id(request) -> int | None:
    return getattr(request, "user_id", None)


def get_order(request, order_id: int) -> Order:
    user_id = get_current_user_id(request)
    if user_id is None:
        raise PermissionError("unauthorized")

    order = ORDERS.get(order_id)
    if order is None:
        raise KeyError("order not found")

    return order
