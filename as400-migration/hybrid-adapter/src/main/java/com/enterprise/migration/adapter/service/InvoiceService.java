package com.enterprise.migration.adapter.service;

import com.enterprise.migration.adapter.dto.InvoiceResponse;

public interface InvoiceService {
    InvoiceResponse getInvoice(String invId);
}

