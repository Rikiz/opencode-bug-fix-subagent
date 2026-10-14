Title: percent_decode() does not turn "+" into a space

Observed:
  percent_decode("first+name") returns "first+name".
  Our form parser reads the value as "first+name" instead of "first name", so
  the lookup fails for any address that contains a space.

Expected:
  percent_decode("first+name") == "first name".
  percent_decode("first%20name") == "first name" (already works).
  Text with no escapes is returned unchanged, and a malformed "%" is left as-is.

Location: `percent_decode` is declared once, in src/lib.rs.
Environment: stable Rust, no dependencies.
