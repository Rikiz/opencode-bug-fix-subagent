import com.example.invoice.Invoice;

/** Plain-Java oracle: no test framework is available in this repository. */
public final class InvoiceOracle {

    private static int failures = 0;

    static void expect(long expected, long actual, String what) {
        if (expected != actual) {
            System.out.println("FAIL " + what + ": expected " + expected + " but got " + actual);
            failures++;
        } else {
            System.out.println("ok   " + what + " = " + actual);
        }
    }

    public static void main(String[] args) {
        expect(1099L, Invoice.totalWithTax(999L, 10), "tax rounds half-up (999 @ 10%)");
        expect(1100L, Invoice.totalWithTax(1000L, 10), "exact division unchanged (1000 @ 10%)");
        expect(0L, Invoice.totalWithTax(0L, 10), "zero subtotal");
        expect(1000L, Invoice.totalWithTax(1000L, 0), "zero rate");
        expect(1200L, Invoice.totalWithTax(1000L, 20), "flat 20%");
        expect(1750L, Invoice.totalWithTax(1000L, 75), "high rate (1000 @ 75%)");
        if (failures > 0) {
            System.out.println(failures + " check(s) failed");
            System.exit(1);
        }
        System.out.println("all checks passed");
    }
}
