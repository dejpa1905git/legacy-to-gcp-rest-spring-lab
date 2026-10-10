package com.enterprise.migration.adapter.exception;

/**
 * Thrown when the upstream IBM i (AS/400) host cannot be reached due to
 * scheduled maintenance, host reboot, network outage, or connection timeout.
 */
public class IbmiHostUnavailableException extends RuntimeException {

    private final String invoiceId;
    private final String targetHost;
    private final String details;

    public IbmiHostUnavailableException(String invoiceId, String targetHost, String details, Throwable cause) {
        super("Cannot reach upstream host '" + targetHost + "': " + details, cause);
        this.invoiceId = invoiceId;
        this.targetHost = targetHost;
        this.details = details;
    }

    public String getInvoiceId() {
        return invoiceId;
    }

    public String getTargetHost() {
        return targetHost;
    }

    public String getDetails() {
        return details;
    }
}

