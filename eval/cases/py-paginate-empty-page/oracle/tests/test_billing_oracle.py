import unittest

from invoice.billing import paginate


class TestPaginate(unittest.TestCase):
    def test_single_page_returns_one_page(self):
        self.assertEqual(paginate([1, 2, 3], 5), [[1, 2, 3]])

    def test_exact_fit_returns_one_page(self):
        self.assertEqual(paginate([1, 2, 3], 3), [[1, 2, 3]])

    def test_empty_input_returns_no_pages(self):
        self.assertEqual(paginate([], 3), [])

    def test_multiple_pages(self):
        self.assertEqual(paginate([1, 2, 3, 4], 2), [[1, 2], [3, 4]])

    def test_last_partial_page(self):
        self.assertEqual(paginate([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]])

    def test_page_size_one(self):
        self.assertEqual(paginate([7], 1), [[7]])

    def test_rejects_non_positive_page_size(self):
        with self.assertRaises(ValueError):
            paginate([1], 0)


if __name__ == "__main__":
    unittest.main()
