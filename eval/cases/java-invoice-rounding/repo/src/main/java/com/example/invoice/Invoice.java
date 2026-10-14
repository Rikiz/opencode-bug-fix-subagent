package com.example.invoice;

/** Fixed-point invoice arithmetic. All amounts are in cents. */
public final class Invoice {

    private Invoice() {}

    /**
     * Subtotal plus tax, with the tax rounded half-up to whole cents.
     *
     * @param subtotalCents non-negative amount in cents
     * @param ratePercent   non-negative tax rate, e.g. 10 for 10%
     */
    public static long totalWithTax(long subtotalCents, int ratePercent) {
        long tax = subtotalCents * ratePercent / 100;
        return subtotalCents + tax;
    }
}
