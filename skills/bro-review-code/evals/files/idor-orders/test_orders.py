from types import SimpleNamespace

from orders import get_order


def test_owner_can_read_own_order():
    request = SimpleNamespace(user_id=10)
    order = get_order(request, 1)
    assert order.id == 1


def test_missing_order_raises():
    request = SimpleNamespace(user_id=10)
    try:
        get_order(request, 999)
        assert False, "expected KeyError"
    except KeyError:
        pass

