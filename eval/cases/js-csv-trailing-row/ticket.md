Title: parseRows() returns a phantom empty row when the file ends with a newline

Observed:
  parseRows("a,b\n1,2\n") returns [["a","b"], ["1","2"], [""]] — three rows.
  Our importer then writes a trailing empty record to the database and the
  nightly reconciliation job fails with a unique-constraint violation.

Expected:
  parseRows("a,b\n1,2\n") returns [["a","b"], ["1","2"]] — two rows.
  A trailing newline terminates the last record; it does not start a new one.
  parseRows("a,b\n1,2") (no trailing newline) must keep returning two rows.

Environment: Node 23, CommonJS, no dependencies.
The reporter attached a screenshot of the database error but no file path; the
function name `parseRows` is unique in the repo.
