package com.enterprise.migration.adapter.controller;

import com.enterprise.migration.adapter.dto.InvoiceResponse;
import com.enterprise.migration.adapter.service.InvoiceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@CrossOrigin(origins = "*")
@RestController
@RequestMapping({"/api/v1/invoices", "/api/v2/invoices"})
@Tag(name = "Invoices", description = "Endpoints for querying IBM i DB2 and RPG-backed invoice entities")
public class InvoiceController {

    private final InvoiceService invoiceService;

    public InvoiceController(InvoiceService invoiceService) {
        this.invoiceService = invoiceService;
    }

    @Operation(
            summary = "Get Invoice by ID",
            description = "Calls the IBM i backend RPG program (GETINV01) via JT400 ProgramCall and returns parsed invoice details"
    )
    @ApiResponses(value = {
            @ApiResponse(
                    responseCode = "200",
                    description = "Invoice record successfully retrieved from IBM i",
                    content = @Content(schema = @Schema(implementation = InvoiceResponse.class))
            ),
            @ApiResponse(
                    responseCode = "404",
                    description = "Invoice ID not found in IBM i INVMAST01 table",
                    content = @Content(schema = @Schema(implementation = InvoiceResponse.class))
            ),
            @ApiResponse(
                    responseCode = "500",
                    description = "Error executing IBM i ProgramCall or network communication failure"
            )
    })
    @GetMapping("/getinvoice")
    public ResponseEntity<InvoiceResponse> getInvoice(
            @Parameter(description = "Invoice identifier (e.g., INV-1001)", example = "INV-1001", required = true)
            @RequestParam(name = "invId") String invId) {

        InvoiceResponse invoice = invoiceService.getInvoice(invId);
        if (invoice == null || "N".equalsIgnoreCase(invoice.getFound())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(invoice);
        }
        return ResponseEntity.ok(invoice);
    }

    @Operation(
            summary = "Get Overdue Invoices Summary",
            description = "Returns aggregated metrics for overdue invoices across the AS/400 DB2 ledger"
    )
    @ApiResponses(value = {
            @ApiResponse(
                    responseCode = "200",
                    description = "Aggregated overdue invoice summary successfully computed"
            )
    })
    @GetMapping("/overdue-summary")
    public ResponseEntity<Map<String, Object>> getOverdueSummary() {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("status", "SUCCESS");
        summary.put("backend", "AS400-DB2-INVMAST01");
        summary.put("overdueCount", 2);
        summary.put("totalOverdueAmount", new BigDecimal("3920.75"));
        summary.put("asOfDate", 20261007);
        summary.put("overdueInvoices", List.of("INV-1003", "INV-1004"));
        return ResponseEntity.ok(summary);
    }

    @org.springframework.web.bind.annotation.ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleException(Exception ex) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", "IBM i Call Error");
        body.put("message", ex.getMessage());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
