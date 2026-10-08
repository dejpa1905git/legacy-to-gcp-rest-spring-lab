package com.enterprise.migration.adapter.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

@Schema(description = "Invoice response payload mapped from IBM i DB2 INVMAST01 and GETINV01 RPG program")
@JsonInclude(JsonInclude.Include.NON_NULL)
public class InvoiceResponse {

    @Schema(description = "Due date in YYYYMMDD format", example = "20261115")
    @JsonProperty("duDate")
    private Long duDate;

    @Schema(description = "Customer account number", example = "100001")
    @JsonProperty("custNo")
    private Long custNo;

    @Schema(description = "Total invoice amount", example = "1250.00")
    @JsonProperty("invAmt")
    private BigDecimal invAmt;

    @Schema(description = "Invoice status: 'O'=Open, 'P'=Paid, 'X'=Overdue", example = "O")
    @JsonProperty("status")
    private String status;

    @Schema(description = "Query status: 'Y'=Found, 'N'=Not Found, 'E'=Error", example = "Y")
    @JsonProperty("found")
    private String found;

    public InvoiceResponse() {
    }

    public InvoiceResponse(Long duDate, Long custNo, BigDecimal invAmt, String status, String found) {
        this.duDate = duDate;
        this.custNo = custNo;
        this.invAmt = invAmt;
        this.status = status;
        this.found = found;
    }

    public Long getDuDate() {
        return duDate;
    }

    public void setDuDate(Long duDate) {
        this.duDate = duDate;
    }

    public Long getCustNo() {
        return custNo;
    }

    public void setCustNo(Long custNo) {
        this.custNo = custNo;
    }

    public BigDecimal getInvAmt() {
        return invAmt;
    }

    public void setInvAmt(BigDecimal invAmt) {
        this.invAmt = invAmt;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getFound() {
        return found;
    }

    public void setFound(String found) {
        this.found = found;
    }
}
