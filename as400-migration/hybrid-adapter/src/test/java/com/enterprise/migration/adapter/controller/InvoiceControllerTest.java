package com.enterprise.migration.adapter.controller;

import com.enterprise.migration.adapter.dto.InvoiceResponse;
import com.enterprise.migration.adapter.service.InvoiceService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(InvoiceController.class)
class InvoiceControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private InvoiceService invoiceService;

    @Test
    @DisplayName("GET /api/v1/invoices/getinvoice returns 200 with duDate, custNo, invAmt")
    void shouldReturnInvoiceDetails() throws Exception {
        InvoiceResponse mockInvoice = new InvoiceResponse(
                20261001L,
                2L,
                new BigDecimal("3920.75"),
                "O",
                "Y"
        );

        Mockito.when(invoiceService.getInvoice("INV-1001")).thenReturn(mockInvoice);

        mockMvc.perform(get("/api/v1/invoices/getinvoice")
                        .param("invId", "INV-1001")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.duDate", is(20261001)))
                .andExpect(jsonPath("$.custNo", is(2)))
                .andExpect(jsonPath("$.invAmt", is(3920.75)))
                .andExpect(jsonPath("$.status", is("O")))
                .andExpect(jsonPath("$.found", is("Y")));
    }

    @Test
    @DisplayName("GET /api/v1/invoices/getinvoice returns 404 when invoice not found")
    void shouldReturn404WhenNotFound() throws Exception {
        InvoiceResponse mockNotFound = new InvoiceResponse(
                null,
                null,
                null,
                "",
                "N"
        );

        Mockito.when(invoiceService.getInvoice("INV-9999")).thenReturn(mockNotFound);

        mockMvc.perform(get("/api/v1/invoices/getinvoice")
                        .param("invId", "INV-9999")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.found", is("N")));
    }
}

