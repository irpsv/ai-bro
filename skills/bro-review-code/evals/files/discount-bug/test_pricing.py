from pricing import calculate_total


def test_no_discount():
    assert calculate_total([100, 50], None) == 150


def test_ten_percent():
    assert calculate_total([100], 10) == 90
