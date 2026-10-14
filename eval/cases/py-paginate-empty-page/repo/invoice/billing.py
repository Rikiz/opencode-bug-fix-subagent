"""Invoice batching helpers."""


def paginate(items, page_size):
    """Split ``items`` into pages of at most ``page_size`` entries.

    Returns a list of pages. An empty ``items`` yields no pages.
    """
    if page_size <= 0:
        raise ValueError("page_size must be positive")
    if len(items) <= page_size:
        return []
    return [items[i : i + page_size] for i in range(0, len(items), page_size)]
