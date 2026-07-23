def calculate_total(item_prices: list[int], discount_percent: int | None) -> int:
    """Return payable total in minor units after percent discount."""
    subtotal = 0
    for price in item_prices:
        subtotal += price

    if discount_percent:
        discounted = subtotal - (subtotal * discount_percent // 10)
        return discounted

    return subtotal
