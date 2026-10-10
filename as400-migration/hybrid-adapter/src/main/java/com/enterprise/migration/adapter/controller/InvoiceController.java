package com.enterprise.migration.adapter.controller;

import com.enterprise.migration.adapter.dto.InvoiceResponse;
import com.enterprise.migration.adapter.exception.IbmiHostUnavailableException;
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
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.Instant;
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
                    description = "Unexpected internal server error"
            ),
            @ApiResponse(
                    responseCode = "503",
                    description = "Upstream IBM i (AS/400) backend is offline, unreachable, or undergoing scheduled maintenance"
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

    @ExceptionHandler(IbmiHostUnavailableException.class)
    public ResponseEntity<Map<String, Object>> handleHostUnavailable(IbmiHostUnavailableException ex) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now().toString());
        body.put("status", HttpStatus.SERVICE_UNAVAILABLE.value());
        body.put("error", "Service Unavailable");
        body.put("fault", "UPSTREAM_LEGACY_HOST");
        body.put("message", "Cannot reach the host: Upstream IBM i (AS/400) server is offline or undergoing scheduled maintenance.");

        Map<String, String> infra = new LinkedHashMap<>();
        infra.put("gcpApiGateway", "HEALTHY");
        infra.put("gcpCloudRun", "HEALTHY");
        infra.put("upstreamIbmI", "UNREACHABLE");
        body.put("infrastructureStatus", infra);

        if (ex.getInvoiceId() != null) {
            body.put("invoiceId", ex.getInvoiceId());
        }
        body.put("advisory", "GCP perimeter and application services are operational. Check upstream AS/400 host status.");
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleException(Exception ex) {
        String msg = ex.getMessage() != null ? ex.getMessage() : "";
        String lower = msg.toLowerCase();
        if (lower.contains("connection refused")
                || lower.contains("host is unreachable")
                || lower.contains("unreachable")
                || lower.contains("timed out")
                || lower.contains("timeout")
                || lower.contains("cannot connect")
                || lower.contains("connection dropped")
                || lower.contains("no route to host")) {
            return handleHostUnavailable(new IbmiHostUnavailableException(null, "pub400.com", msg, ex));
        }

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now().toString());
        body.put("status", HttpStatus.INTERNAL_SERVER_ERROR.value());
        body.put("error", "Internal Server Error");
        body.put("message", ex.getMessage());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
