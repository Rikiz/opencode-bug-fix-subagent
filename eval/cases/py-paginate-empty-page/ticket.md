Title: paginate() returns no pages when the list fits on one page

Version: 1.4.0

Observed:
  paginate([1, 2, 3], 5) returns `[]`. Our import then treats the report as having zero rows and the dashboard shows a blank table.
  paginate([1, 2, 3, 4], 2) returns `[[1, 2], [3, 4]]`, so splitting works fine when there is more than one page.

Expected:
  paginate([1, 2, 3], 5) returns `[[1, 2, 3]]` — a single page containing every item.
  A list that fits within the page size is one page, not zero pages.

Environment: Python 3.12, no dependencies.

Note: the reporter did not say which file or function to change. Steps are not
provided, but the observed and expected calls above are copy-pasteable.
