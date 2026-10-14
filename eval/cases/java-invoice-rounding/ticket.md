Title: Invoice.totalWithTax under-reports the tax by a cent on round totals

Observed:
  Invoice.totalWithTax(999, 10) returns 1098.
  9.99 with 10% tax is 10.99, i.e. 1099 cents in our fixed-point representation.

Expected:
  The tax is rounded half-up, so Invoice.totalWithTax(999, 10) returns 1099.
  Rounding only applies to the tax component; the subtotal is already in cents.

Environment: Java 17, no build tool in this repository — compile with javac.
The reporter did not name a file. There is exactly one class named Invoice.
